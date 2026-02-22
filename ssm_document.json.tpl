{
  "schemaVersion": "2.2",
  "description": "Run Ansible Playbook",
  "mainSteps": [
    {
      "action": "aws:runAnsiblePlaybook",
      "name": "runAnsiblePlaybook",
      "inputs": {
        "playbook": ${playbook_content},
        "check": "False",
        "verbose": "-v"
      }
    }
  ]
}
