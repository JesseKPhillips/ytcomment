# YouTube Comments Exporter

This script reads an export YouTube comments from a CSV file and generates a http server for further processing. Each comment is served by a requested comment ID, which is just an index in the list of comment.

## How to Use

1. Go to Google's Data Export Utility
2. Request Comments be exported
3. Obtain Comments from your email
4. Run the Script: Execute the script by providing a port and passing the path to your CSV file

   ```bash
   dub build
   ./ytcomment <port> <path_to_your_csv_file>
   ```

5. **Runs HTTP Server**: You may need to execute as root and setup lowering: https://vibed.org/docs#privilege-lowering

6. **Using the Server**: https://127.0.0.1:<port>/comments/<num>
