Execute the complete TestFlight deployment workflow: check code quality, optionally bump version, build, upload, and assign to beta testers.

Run the deployment script: `./deploy_testflight.sh`

This single command handles everything:
- ✅ Code quality checks (flutter analyze)
- ✅ Version management (asks if you want to bump)
- ✅ Clean build process
- ✅ IPA generation for release
- ✅ TestFlight upload via API
- ✅ Auto-assignment to "Beta Testers!" group
- ✅ Status updates throughout

Total time: ~3 minutes to complete, then 10-90 minutes for Apple processing.
Your public TestFlight link will automatically include the new build once processed.