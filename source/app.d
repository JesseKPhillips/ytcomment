import std.algorithm;
import std.stdio;
import std.string;
import std.conv;
import std.datetime;
import dateparser;
import std.csv;
import std.file;
import std.path;
import std.range;
import iopipe.json.parser;
import iopipe.json.serialize;

struct csvContent {
    string commentId;
    string channelId;
    string creationTime;
    int price;
    string parentCommentId;
    string postId;
    string videoId;
    CommentStruct[] comment;
    string opCommentId;
    bool deleted;
}

// Extract the comment id, video id, and comment text from the row
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


void main(string[] args) {
    // Open the CSV file for reading
    auto file = args[1];
    if (!file.exists) {
        writeln("CSV file not found.");
        return;
    }

    auto csvFile = readText(file).strip;

    // Create a CSV reader
    auto records = csvReader!(string[string])(csvFile, null);

    // Open a new Markdown file for writing
    auto mdfilename = file.setExtension(".md");
    auto markdownFile = File(mdfilename, "w");

    // Write the header to the Markdown file
    markdownFile.writeln("# YouTube Comments");

    auto makeRow(string[string] dic) {
        enum parseConf = ParseConfig(true);

        csvContent row;
        row.commentId = dic["Comment ID"];
        row.videoId = dic["Video ID"];
        row.channelId = dic["Channel ID"];
        row.creationTime = dic["Comment Create Timestamp"];
        row.parentCommentId = dic["Parent Comment ID"];
        if("Post ID" in dic)
            row.postId = dic["Post ID"];
        row.videoId = dic["Video ID"];
        row.opCommentId = dic["Top-Level Comment ID"];

        auto parser = text("[", dic["Comment Text"], "]").to!(char[]).jsonTokenizer!parseConf;
        row.comment = parser.deserialize!(CommentStruct[]);

        if(row.videoId.startsWith(" -")) {
            row.videoId = row.videoId[2..$];
            row.deleted = true;
        }

        return row;
    }

    // Read each row of data
    foreach(row; records.map!makeRow) {
        // Parse the JSON text to extract the comment text
        string commentText;
        string postOrVideo;
        if(!row.videoId.empty)
            postOrVideo = "watch?v=" ~ row.videoId ~ "&";
        else if(!row.postId.empty)
            postOrVideo = "post/" ~ row.postId ~ "?";
        else
            throw new Exception("Is it a Post or Video?");
        string[] links = ["https://www.youtube.com/" ~ postOrVideo ~ "lc=" ~ row.commentId];
        foreach(comment; row.comment) {
            auto txt = comment.text
                .replace("\u200b", "");
            if(txt.empty)
                continue;

            if(!comment.videoLink.externalVideoId.empty) {
                if(comment.videoLink.startTimeSeconds != 0) {
                    if(commentText.empty && row.videoId == comment.videoLink.externalVideoId)
                        links[0] ~= text("&s=", comment.videoLink.startTimeSeconds);
                    else
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
                    commentText ~= text(comment.text[1..$], "[", links.length, "] ");
            } else {
                if(txt.startsWith("@"))
                    txt = txt[1..$] ~ " ";
                commentText ~= txt;
            }

        }

        // Write the Markdown entry
        markdownFile.writeln(commentText);
        markdownFile.writeln();
        markdownFile.writeln("Original Comment");
        markdownFile.writeln("================");
        markdownFile.writeln("1. " ~ (row.deleted?"[deleted] ":"") ~ links.front);
        markdownFile.writeln("*"~parse(row.creationTime).toSimpleString~"*");
        if(!row.parentCommentId.empty)
            markdownFile.writeln("Parent Comment: https://www.youtube.com/" ~ postOrVideo ~ "lc=" ~ row.parentCommentId);
        if(!row.opCommentId.empty && row.opCommentId != row.parentCommentId)
            markdownFile.writeln("Conversation OP: https://www.youtube.com/" ~ postOrVideo ~ "lc=" ~ row.opCommentId);
        markdownFile.writeln();

        foreach(i, l; links[1..$]) {
            markdownFile.writeln(format("%s. %s", i+2, l));
        }
        markdownFile.writeln();
        markdownFile.writeln("------------------------------------");
    }

    // Close the files
    markdownFile.close();
}
