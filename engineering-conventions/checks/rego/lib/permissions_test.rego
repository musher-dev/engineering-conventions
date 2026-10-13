package conventions.lib.permissions_test

import data.conventions.lib.permissions

test_job_permissions_replace_the_workflow_permissions if {
	workflow := {"permissions": {"artifact-metadata": "write"}}
	permissions.granted(workflow, {}, "artifact-metadata")
	permissions.granted({}, {"permissions": "write-all"}, "artifact-metadata")
	not permissions.granted(workflow, {"permissions": {"contents": "read"}}, "artifact-metadata")
	not permissions.granted({"permissions": {"artifact-metadata": "read"}}, {}, "artifact-metadata")
}
