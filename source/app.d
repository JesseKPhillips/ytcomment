import std.algorithm;
import std.stdio;
import std.string;
import std.conv;
import std.datetime;
import dateparser;
import std.csv;
import std.file;
import std.path;
import iopipe.json.parser;
import iopipe.json.serialize;

struct csvContent {
    string commentId;
    string channelId;
    string creationTime;
    int price;
    string parentCommentId;
    string videoId;
    string commentJson;
    string opCommentId;
}

void main() {
    // Open the CSV file for reading
    auto file = "commentdata/comments(3).csv";
    if (!file.exists) {
        writeln("CSV file not found.");
        return;
    }

    auto csvFile = readText(file).strip;

    // Create a CSV reader
    auto records = csvReader!csvContent(csvFile, null);

    // Open a new Markdown file for writing
    auto mdfilename = file.setExtension(".md");
    auto markdownFile = File(mdfilename, "w");

    // Write the header to the Markdown file
    markdownFile.writeln("# YouTube Comments");

    // Read each row of data
    foreach(row; records) {
        // Extract the comment id, video id, and comment text from the row
        string commentId = row.commentId;
        string videoId = row.videoId;
        string jsonText = row.commentJson;

        struct CommentStruct {
            string text;
            @optional
            Mention mention;
            @optional
            VideoLink videoLink;
            @optional
            string[string] link;
            struct Mention {
                string externalChannelId;
            }
            struct VideoLink {
                string externalVideoId;
                @optional
                uint startTimeSeconds;
            }
        }

        enum parseConf = ParseConfig(true);

        auto parser = text("[", jsonText, "]").to!(char[]).jsonTokenizer!parseConf;
        // Parse the JSON text to extract the comment text
        string commentText;
        string[] links;
        foreach(comment; parser.deserialize!(CommentStruct[])) {
            auto txt = comment.text
                .replace("\u200b", "");
            if(txt.empty)
                continue;

            if(!comment.videoLink.externalVideoId.empty) {
                if(comment.videoLink.startTimeSeconds != 0) {
                    links ~= text("https://youtu.be/"
                                  , comment.videoLink.externalVideoId
                                  , "?s=", comment.videoLink.startTimeSeconds);
                    commentText ~= text(comment.text, "[", links.length, "]");
                } else {
                    links ~= text("https://youtu.be/"
                                  , comment.videoLink.externalVideoId);
                    commentText ~= text("[", links.length, "]");
                }
            } else if(!comment.mention.externalChannelId.empty) {
                    links ~= text("https://www.youtube.com/channel/"
                                  , comment.mention.externalChannelId);
                    commentText ~= text(comment.text, "[", links.length, "] ");
            } else {
                commentText ~= txt;
                if(txt.startsWith("@"))
                    commentText ~= " ";
            }

        }

        // Write the Markdown entry
        markdownFile.writeln(commentText);
        markdownFile.writeln();
        foreach(i, l; links) {
            markdownFile.writeln(format("%s. %s", i+1, l));
        }
        markdownFile.writeln();
        markdownFile.writeln("Original Comment");
        markdownFile.writeln("================");
        markdownFile.writeln("https://www.youtube.com/watch?v=" ~ videoId ~ "&lc=" ~ commentId);
        markdownFile.writeln("*"~parse(row.creationTime).toSimpleString~"*");
        markdownFile.writeln();
        markdownFile.writeln("----");
    }

    // Close the files
    markdownFile.close();
}
