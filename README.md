# YouTube Comments Exporter

This script exports YouTube comments from a CSV file and generates a Markdown file for further processing. The output can be used to create a comprehensive list of comments with links to videos or posts.

## How to Use

1. **Prepare Your CSV File**: Ensure your CSV file is in the correct format, with columns named `Comment ID`, `Channel ID`, `Comment Create Timestamp`, `Price`, `Parent Comment ID`, `Post ID`, `Video ID`, `Comment Text`, and `Top-Level Comment ID`.

2. **Run the Script**: Execute the script by passing the path to your CSV file as an argument.

   ```bash
   dub run --build=release source/app.d <path_to_your_csv_file>
   ```

3. **Generate Markdown File**: The script will create a new Markdown file in the same directory as your input CSV file, with a `.md` extension.

4. **Use the Markdown Output**: You can use this Markdown file to further process or analyze the comments as needed.

## Example

Suppose you have a CSV file named `comments.csv` and run the script:

