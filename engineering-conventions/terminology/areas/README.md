# Area overlays

An area overlay adds terminology for one bounded part of the organisation on
top of [`global.yml`](../global.yml). No areas exist yet: every term in use
applies everywhere.

## Adding an area

1. Create `areas/<area>.yml`, where `<area>` is a lower-case kebab-case slug.
   Its `area:` field must equal the filename.
2. Add terms with IDs that do not exist globally, aliases on global terms
   under `extend`, and display forms for tokens the global file does not
   list:

   ```yaml
   schema_version: 1
   area: example-area
   description: Words specific to the example area.
   terms:
     - id: example-area.widget
       display_name: widget
       definition: A thing the example area builds.
       tags: [example-area]
       stability: provisional
   extend:
     - term: gha.responsibility.deploy
       aliases:
         - text: push-live
           status: banned
           scope: [identifier]
   display_forms:
     - token: grpc
       display: gRPC
   ```

3. Run `conventions invariants`. It fails if the overlay redefines a global
   term, display form or alias.

A consuming repository opts into an area with `area:` in its conventions
declaration.
