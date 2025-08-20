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
    SysTime creationTime;
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
    if (args.length < 3) {
        writeln("Usage: vibe-test.exe <port> <csv-file>");
        return;
    }

    int port = parseInt(args[1]);
    auto csvFile = args[2];

    // Open the CSV file for reading
    if (!file.exists(csvFile)) {
        writeln("CSV file not found.");
        return;
    }

    auto csvFileContent = readText(csvFile).strip;

    // Create a CSV reader
    auto records = csvReader!(string[string])(csvFileContent, null);

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
        row.creationTime = parse(dic["Comment Create Timestamp"]);
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

    auto allComments = records.map!makeRow.array.sort!"a.creationTime < b.creationTime";

    csvContent[][] treeComments;

    foreach(v; allComments) {
        bool found;
        foreach(ref t; treeComments) {
            if(!v.parentCommentId.empty && t.front.parentCommentId == v.parentCommentId)
                found = true;
            if(!v.opCommentId.empty && t.front.parentCommentId == v.opCommentId)
                found = true;
            if(!v.opCommentId.empty && t.front.opCommentId == v.opCommentId)
                found = true;
            if(!v.parentCommentId.empty && t.front.opCommentId == v.parentCommentId)
                found = true;

            if(found) {
                t ~= v;
                break;
            }
        }
        if(!found)
            treeComments ~= [v];
    }

    auto getCommentById(string commentId) {
        foreach(row; treeComments.joiner) {
            if(row.commentId == commentId) return row;
        }
        return null;
    }

    // Handle requests for individual comments
    void handleCommentRequest(HTTPServerRequest req, HTTPServerResponse res) {
        string commentId = req.queryParams["commentId"];
        auto comment = getCommentById(commentId);

        if(!comment) {
            res.statusCode = HTTPStatus.notFound;
            res.write("Comment not found.");
            return;
        }

        // Parse the JSON text to extract the comment text
        string commentText;
        string postOrVideo;
        if(!comment.videoId.empty)
            postOrVideo = "watch?v=" ~ comment.videoId ~ "&";
        else if(!comment.postId.empty)
            postOrVideo = "post/" ~ comment.postId ~ "?";
        else
            throw new Exception("Is it a Post or Video?");
        string[] links = ["https://www.youtube.com/" ~ postOrVideo ~ "lc=" ~ comment.commentId];
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
        markdownFile.writeln("*"~row.creationTime.toSimpleString~"*");
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

    // Set up the HTTP server
    auto settings = new HTTPServerSettings;
    settings.port = port;

    auto router = new URLRouter;
    router.get("/comments/:commentId", &handleCommentRequest);

    listenHTTP(settings, router);

    runApplication();
}
