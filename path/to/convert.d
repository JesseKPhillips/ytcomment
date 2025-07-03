import std.stdio;
import std.csv;
import std.json;

void main() {
    // Open the CSV file for reading
    auto csvFile = File("commentdata/comments.csv");
    if (!csvFile.exists) {
        writeln("CSV file not found.");
        return;
    }

    // Create a CSV reader
    auto csvReader = CsvReader(csvFile);

    // Read the header row
    auto headers = csvReader.readRow();
    if (headers.length == 0) {
        writeln("No data in CSV file.");
        return;
    }

    // Open a new Markdown file for writing
    auto markdownFile = File("commentdata/comments.md", FileMode.write);
    if (!markdownFile.exists) {
        writeln("Markdown file not created.");
        return;
    }

    // Write the header to the Markdown file
    markdownFile.writeln("# YouTube Comments");

    // Read each row of data
    while (true) {
        auto row = csvReader.readRow();
        if (row.length == 0) break;

        // Extract the comment id, video id, and comment text from the row
        string commentId = row[0];
        string videoId = row[1];
        string jsonText = row[2];

        // Parse the JSON text to extract the comment text
        auto jsonValue = parseJson(jsonText);
        if (jsonValue is JsonString) {
            string commentText = jsonValue.toString();
        } else {
            writeln("Invalid JSON format for comment: ", jsonText);
            continue;
        }

        // Write the Markdown entry
        markdownFile.writeln("## Comment ID: ", commentId);
        markdownFile.writeln("### Video ID: ", videoId);
        markdownFile.writeln("#### Comment Text:");
        markdownFile.writeln(commentText);
        markdownFile.writeln("---");
    }

    // Close the files
    csvFile.close();
    markdownFile.close();
}
