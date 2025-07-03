import std.stdio;
import std.conv;
import std.csv;
import std.file;
import iopipe.json.dom;

struct csvContent {
    string commentId;
    string channelId;
    string CreationTime;
    int price;
    string parentCommentId;
    string videoId;
    string commentJson;
    string opCommentId;
}

void main() {
    // Open the CSV file for reading
    auto file = "commentdata/comments.csv";
    if (!file.exists) {
        writeln("CSV file not found.");
        return;
    }

    auto csvFile = readText(file);

    // Create a CSV reader
    auto records = csvReader!csvContent(csvFile, null);

    // Open a new Markdown file for writing
    auto markdownFile = File("commentdata/comments.md", "w");

    // Write the header to the Markdown file
    markdownFile.writeln("# YouTube Comments");

    // Read each row of data
    foreach(row; records) {
        // Extract the comment id, video id, and comment text from the row
        string commentId = row.commentId;
        string videoId = row.videoId;
        string jsonText = row.commentJson;

        // Parse the JSON text to extract the comment text
        auto jsonValue = parseJSON("["~jsonText~"]");
        string commentText;
        foreach(text; jsonValue.array) {
            auto txt = text.object["text"].str;
            if(txt == "\u200b")
                continue;
            commentText ~= txt;
        }

        // Write the Markdown entry
        markdownFile.writeln("## Comment ID: ", "<a href=\"https://www.youtube.com/watch?v=" ~ videoId ~ "#comment-" ~ commentId ~ "\">", commentId, "</a>");
        markdownFile.writeln("### Video ID: ", "<a href=\"https://www.youtube.com/watch?v=" ~ videoId ~ "\">", videoId, "</a>");
        markdownFile.writeln("#### Comment Text:");
        markdownFile.writeln(commentText);
        markdownFile.writeln("---");
    }

    // Close the files
    markdownFile.close();
}
