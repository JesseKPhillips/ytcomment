# YouTube Comments Exporter

This script reads an export YouTube comments from a CSV file and generates a Markdown file for further processing. The output can be used to create a comprehensive list of comments with links to videos or posts.

## How to Use

1. Go to Google's Data Export Utility
2. Request Comments be exported
3. Obtain Comments from your email
4. Run the Script: Execute the script by passing the path to your CSV file as an argument.

   ```bash
   dub run -- <path_to_your_csv_file>
   ```

5. **Generate Markdown File**: The script will create a new Markdown file in the same directory as your input CSV file, with a `.md` extension.

6. **Use the Markdown Output**: You can use this Markdown file to further process or analyze the comments as needed.
