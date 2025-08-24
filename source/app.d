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
import std.typecons;
import iopipe.json.parser;
import vibe.vibe;

csvContent[] sortedComments;


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

struct PageContent {
    string commentText;
    string refLink;
    string timestamp;
    string parentComment;
    string opComment;
    string[] links;
}

// Extract the comment id, video id, and comment text from the row
struct CommentStruct {
import iopipe.json.serialize;
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

    auto port = to!ushort(args[1]);
    auto csvFile = args[2];

    // Open the CSV file for reading
    if (!csvFile.exists) {
        writeln("CSV file not found.");
        return;
    }

    auto csvFileContent = readText(csvFile).strip;

    // Create a CSV reader
    auto records = csvReader!(string[string])(csvFileContent, null);

    auto makeRow(string[string] dic) {
        import iopipe.json.serialize;
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


    auto remove = readText(csvFile.setExtension(".rm"));

    sortedComments = treeComments.joiner
        .filter!(x => indexOf(remove, x.commentId) == -1).array;
    // Set up the HTTP server
    auto settings = new HTTPServerSettings;
    settings.port = port;

    auto router = new URLRouter;
    router.get("/comments/:commentId", &handleCommentRequest);
    router.get("/comments", &handleCommentsRequest);
    router.get("/count/comments", &handleCommentCountRequest);

    listenHTTP(settings, router);

    runApplication();
}

auto getCommentById(uint commentId) {
    foreach(i, row; sortedComments.enumerate) {
        if(i == commentId) return row;
    }
    return csvContent.init;
}

void handleCommentCountRequest(HTTPServerRequest req, HTTPServerResponse res) {
    res.writeBody(sortedComments.length.to!string);
}

void handleCommentsRequest(HTTPServerRequest req, HTTPServerResponse res) {
    string[] pageStr;
    foreach(row; sortedComments) {
        auto comment = makeComment(row);
        pageStr ~= comment[0];
        pageStr ~= makeProlog(row, comment[1]);
    }
    res.writeBody(pageStr.joiner("\n").to!string);
}

void handleCommentRequest(HTTPServerRequest req, HTTPServerResponse res) {
    string commentId = req.params["commentId"];
    auto row = getCommentById(to!uint(commentId));

    if(row.comment.empty) {
        res.statusCode = HTTPStatus.notFound;
        res.write("Comment not found.");
        return;
    }

    string[] pageStr;
    auto comment = makeComment(row);
    pageStr ~= comment[0];
    pageStr ~= makeProlog(row, comment[1]);

    res.writeBody(pageStr.joiner("\n").to!string);
}

Tuple!(string, PageContent) makeComment(csvContent row) {
    // Parse the JSON text to extract the comment text
    string postOrVideo;
    if(!row.videoId.empty)
        postOrVideo = "watch?v=" ~ row.videoId ~ "&";
    else if(!row.postId.empty)
        postOrVideo = "post/" ~ row.postId ~ "?";
    else
        throw new Exception("Is it a Post or Video?");

    string[] links = ["https://www.youtube.com/" ~ postOrVideo ~ "lc=" ~ row.commentId];
    string commentText;
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

    auto page = PageContent(commentText
                            , "1. " ~ (row.deleted?"[deleted] ":"") ~ links.front
                            , "*"~row.creationTime.toSimpleString~"*");

    if(!row.parentCommentId.empty)
        page.parentComment = "Parent Comment: https://www.youtube.com/" ~ postOrVideo ~ "lc=" ~ row.parentCommentId;
    if(!row.opCommentId.empty && row.opCommentId != row.parentCommentId)
        page.opComment = "Conversation OP: https://www.youtube.com/" ~ postOrVideo ~ "lc=" ~ row.opCommentId;

    page.links = links[1..$];

    // Write the Markdown entry
    return tuple(commentText, page);
}

string[] makeProlog(csvContent row, PageContent page) {
    string[] pageStr;

    // Write the Markdown entry
    pageStr ~= "";
    pageStr ~= "Original Comment";
    pageStr ~= "================";
    pageStr ~= page.refLink;
    pageStr ~= page.timestamp;
    if(!page.parentComment.empty)
        pageStr ~= page.parentComment;
    if(!page.opComment.empty)
        pageStr ~= page.opComment;
    pageStr ~= "";

    foreach(i, l; page.links) {
        pageStr ~= format("%s. %s", i+2, l);
    }

    return pageStr;
}
