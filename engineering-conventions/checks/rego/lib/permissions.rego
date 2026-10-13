# METADATA
# title: Job permissions
# description: >-
#   Whether a job's GITHUB_TOKEN is granted a permission: by the job's own
#   permissions, or by the workflow's when the job sets none.
package conventions.lib.permissions

granted(_, job, permission) if {
	"permissions" in object.keys(job)
	grants(job.permissions, permission)
}

granted(workflow, job, permission) if {
	not "permissions" in object.keys(job)
	grants(workflow.permissions, permission)
}

grants("write-all", _)

grants(permissions, permission) if permissions[permission] == "write"
