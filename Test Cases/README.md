AcceptanceCriteriaToTestCases.ps1

This PowerShell script is provided to the public as-is. I find it useful to quickly setup test cases for the forecasted items in my Sprint.

Iterates through all "Product Backlog Item" work items in the "Committed" state (which should be the PBIs forecasted in the current Sprint) and then iterates through all of the items in the "Acceptance Criteria" field, delimitted by numbered/un-numbered HTML list or just <div> tags. For each item, it will create an associated Test Case work item in the current Sprint with the title set to that Acceptance Criteria.

Warning: There is commented-out code in there that will destroy all Test Cases in the team project. You will probably want to edit this before considering using it!

Enjoy!
