resource "aws_ssm_document" "ansible_runbook" {
  name          = "AnsibleRunbook"
  document_type = "Command"

  content = templatefile("${path.module}/ssm_document.json.tpl", {
    playbook_content = jsonencode(file("${path.module}/ansible/site.yml"))
  })
}

resource "aws_ssm_association" "ansible_association" {
  name = aws_ssm_document.ansible_runbook.name

  targets {
    key    = "tag:AnsibleManaged"
    values = ["true"]
  }

  schedule_expression = "rate(30 minutes)" # Or whatever frequency is desired
}
