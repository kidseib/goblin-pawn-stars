# Patches

Temporary transport for changes that touch files too large to send whole through
GitHub's file API. A workflow applies them, runs `npm run verify`, commits the
result and deletes both the patch and the workflow. Nothing should stay here.
