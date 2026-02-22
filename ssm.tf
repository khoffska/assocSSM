resource "aws_ssm_association" "ansible_association" {
  name = "AWS-RunAnsiblePlaybook"

  targets {
    key    = "tag:AnsibleManaged"
    values = ["true"]
  }

  parameters = {
    playbook            = file("${path.module}/ansible/site.yml")
    installDependencies = "True"
  }

  schedule_expression = "rate(30 minutes)"
}
