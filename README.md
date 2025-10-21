Follow these steps to run this script:

1. Install b2 CLI https://www.backblaze.com/docs/cloud-storage-command-line-tools
2. Install jq (brew install jq) https://jqlang.org/download/ 
3. Authenticate to B2 through terminal: b2 account authorize <applicationKeyId> <applicationKey>
4. run ./unhide.sh with arguments <bucket-name> and <prefix/>

You can use "" to iterate over all prefixes

You can add a --dry-run flag to test
