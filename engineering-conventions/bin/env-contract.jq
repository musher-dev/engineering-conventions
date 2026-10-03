# The documents derived from an env.schema.yaml (EC-0019, decisions 0026 and
# 0029): the environment contract, a JSON Schema 2020-12 document (ENVS-20),
# and a developer's local .env, which is generated and never committed. This
# file is the one implementation of the mapping: `conventions env-contract`
# prints the contract and `conventions env-file` writes the .env, and both
# runners (bin/conventions, src/conventions_tools/run.py) give the contract
# to the checks, which only compare.
#
#   input         the schema as conftest parse reads it
#   --arg part    contract, env-file, or derived ({contract}, what the
#                 checks compare)
#
# Run with -S, so the contract's keys are sorted wherever it is printed.

def text: if type == "string" then . else tojson end;

# One line, whitespace collapsed.
def line: text | gsub("\\s+"; " ") | sub("^ "; "") | sub(" $"; "");

def bindings:
  (.bindings // {})
  | if type == "object" then to_entries | map(select(.value | type == "object")) | sort_by(.key) else [] end;

def present($key): has($key) and .[$key] != null;

# A binding's type is the type of its value after the process parses it: an
# environment holds strings, and a validator coerces them first.
def json_type:
  {string: "string", integer: "integer", number: "number", boolean: "boolean", enum: "string", list: "array"}[.type // ""];

def format_keywords:
  if .format == "url" then {format: "uri"}
  elif .format == "email" then {format: "email"}
  elif .format == "json" then {contentMediaType: "application/json"}
  elif .format == "path" then {"x-musher-format": "path"}
  else {} end;

def constraint_keywords:
  (.constraints // {}) as $c
  | if ($c | type) != "object" then {} else
      [
        {key: "min_length", to: "minLength"},
        {key: "max_length", to: "maxLength"},
        {key: "min", to: "minimum"},
        {key: "max", to: "maximum"},
        {key: "pattern", to: "pattern"}
      ]
      | map(.key as $k | select($c | present($k)) | {key: .to, value: $c[$k]})
      | from_entries
    end;

def values_keywords:
  if .type == "list" then
    {items: ({type: "string"} + (if present("values") then {enum: .values} else {} end)), "x-musher-separator": ","}
  elif present("values") then {enum: .values}
  else {} end;

def edge_keywords:
  [
    {key: "sensitivity", to: "x-musher-sensitivity"},
    {key: "capability", to: "x-musher-capability"},
    {key: "provider", to: "x-musher-provider"},
    {key: "target", to: "x-musher-target"},
    {key: "requires", to: "x-musher-requires"}
  ] as $map
  | . as $b
  | $map | map(.key as $k | select($b | present($k)) | {key: .to, value: $b[$k]}) | from_entries;

# A list holds comma-separated values; its default, parsed, is an array.
def list_value: split(",") | map(sub("^\\s+"; "") | sub("\\s+$"; "")) | map(select(. != ""));

def parsed_default: if .type == "list" and (.default | type) == "string" then .default | list_value else .default end;

def property:
  (if json_type then {type: json_type} else {} end)
  + (if present("description") then {description: (.description | line)} else {} end)
  + (if present("default") then {default: parsed_default} else {} end)
  + (if .sensitivity == "secret" then {writeOnly: true} else {} end)
  + format_keywords
  + values_keywords
  + constraint_keywords
  + edge_keywords;

def retired_entry:
  {name, retired_on, reason} + (if present("replacement") then {replacement} else {} end)
  | with_entries(select(.value != null));

def contract:
  . as $schema
  | bindings as $bindings
  | {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$comment": "Generated from env.schema.yaml by conventions env-contract; do not edit.",
      title: (.service // "" | text),
      description: "The environment variables \(.service // "the service" | text) reads, and what each one holds.",
      type: "object",
      properties: ($bindings | map({key, value: (.value | property)}) | from_entries),
      required: ($bindings | map(select(.value.required == true) | .key)),
      additionalProperties: true
    }
  + (if ($schema.requires | type) == "object" and ($schema.requires | length) > 0
      then {"x-musher-requires": $schema.requires} else {} end)
  + (if ($schema.retired | type) == "array" and ($schema.retired | length) > 0
      then {"x-musher-retired": ($schema.retired | map(select(type == "object") | retired_entry))}
      else {} end);

# A value as a .env line holds it: bare when it is plain, in single quotes
# when it holds anything a dotenv reader could interpret, and in double quotes
# with \ and " escaped when it holds a single quote itself.
def dotenv_value:
  text
  | if test("^[A-Za-z0-9_@%+=:,./-]*$") then .
    elif (contains("'") | not) then "'\(.)'"
    else "\"\(gsub("\\\\"; "\\\\") | gsub("\""; "\\\""))\""
    end;

def facts:
  [
    (if .type == "enum" then "enum: \((.values // []) | map(text) | join("|"))"
     elif .type == "list" and present("values") then "list: \(.values | map(text) | join("|"))"
     else (.type // "string" | text) end),
    (if present("format") then .format | text else empty end),
    (if .required == true then "required" else empty end),
    (.sensitivity // empty | text),
    (if present("local_generate") then "generate locally: \(.local_generate | text)" else empty end)
  ]
  | join(", ");

# A binding's line: its local value; a placeholder `conventions env-file`
# replaces with freshly minted material; empty when it must be filled in;
# commented out, with its default, when the code's default applies.
def assignment($name):
  if present("local_default") then "\($name)=\(.local_default | dotenv_value)"
  elif present("local_generate") then "\($name)=@@generate:\(.local_generate | text)@@"
  elif .required == true then "\($name)="
  else "# \($name)=\(if present("default") then .default | dotenv_value else "" end)"
  end;

def env_file:
  (.service // "the service" | text) as $service
  | [
      "# The local environment \($service) reads, generated from its env.schema.yaml by",
      "# conventions env-file. It holds this machine's values and secrets: git ignores",
      "# it (ENVS-27), and it is never committed. Fill in the empty values. After the",
      "# schema changes, run conventions env-file again to list what is missing.",
      (bindings[] | .key as $name | .value | "", "# \(.description // "" | line)", "# \(facts)", assignment($name))
    ]
  | join("\n") + "\n";

if type != "object" then error("an environment schema is a mapping")
elif $part == "env-file" then env_file
elif $part == "derived" then {contract: contract}
else contract
end
