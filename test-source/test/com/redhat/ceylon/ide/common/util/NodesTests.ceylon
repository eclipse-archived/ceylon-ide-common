import ceylon.test {
    test,
    assertEquals
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import ceylon.interop.java {
    CeylonIterable
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Message,
    Tree,
    Node
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    UsageWarning
}
import ceylon.file {
    Directory,
    File,
    lines
}
import ceylon.language.meta.model {
    ClassOrInterface
}
import ceylon.language.meta {
    type
}
import test.com.redhat.ceylon.ide.common.testUtils {
    SourceCode,
    parseAndTypecheckCode,
    resourcesRootForPackage
}

Directory resourcesRoot = resourcesRootForPackage(`package`);

shared class NodesTests() {
    [String*] loadLines(String fileName) {
        assert(is File file=resourcesRoot.childResource(fileName));
        return lines(file);
    }

    Integer calculateContentOffset([String*] lines,
        Boolean findLine(Integer->String line),
        Integer findColumn(String line)) {
            value searchedLines = lines.indexed.select(findLine);
            "Exactly one line should be found"
            assert(exists searchedLine = searchedLines.first,
                searchedLines.size == 1);
            return lines.take(searchedLine.key)
                         .fold(0)(
                                  (p, l)
                                        => p + l.size + 1)
                        + findColumn(searchedLine.item);
    }

    suppressWarnings("unusedDeclaration", "expressionTypeNothing")
    Integer lineColumnToOffset([String*]lines,
        "0-based line index"
        Integer line,
        "0-based column index"
        Integer column)
            => calculateContentOffset {
                lines => lines;
                function findLine(Integer->String l)
                        => l.key == line;
                function findColumn(String l)
                        => if (column < l.size)
                                then column
                                else nothing;
            };

    suppressWarnings("expressionTypeNothing")
    Integer findInLines([String*]lines,
        String searchedText,
        Integer indexInText)
            => calculateContentOffset {
                lines => lines;
                function findLine(Integer->String l)
                        => l.item.contains(searchedText);
                function findColumn(String line)
                        => if (exists textStart = line.firstInclusion(searchedText))
                                then textStart + indexInText
                                else nothing;
            };

    String fileName = "NodesTests_findNode.ceylon";
    [String*] theLines = loadLines(fileName);
    String contents = "\n".join(theLines);
    value pu = parseAndTypecheckCode {
        SourceCode {
            path = fileName;
            contents = contents;
        }
    }.first?.item;
    assert(exists pu);
    assertEquals(CeylonIterable(pu.compilationUnit.errors)
        .filter((Message message) => !(message is UsageWarning)).sequence(), []);

    String? toString(Node? node)
        => if (exists start=node?.startIndex?.intValue())
            then if (exists stop=node?.stopIndex?.intValue())
                    then contents.span(start, stop)
                    else contents.spanFrom(start)
            else null;

    void test(String searchedText, Integer startIndexInSearchedText, Integer endIndexInSearchedText, [ClassOrInterface<Node>, String]? expectedNode) {
        value startOffset = findInLines(theLines, searchedText, startIndexInSearchedText);
        value endOffset = findInLines(theLines, searchedText, endIndexInSearchedText);
        value found = nodes.findNode(pu.compilationUnit, pu.tokens, startOffset, endOffset);
        function format([ClassOrInterface<Node?>, String?]? result)
                => if (is [ClassOrInterface<Node>, String] result)
                        then "\n" + "\n".join(result) + "\n"
                        else null;
        assertEquals {
            actual = format([type(found), toString(found)]);
            expected = format(expectedNode);
            message = "Wrong node found for selection :
                        ``
                        let(selectionSize=endIndexInSearchedText-startIndexInSearchedText)
                            searchedText.spanTo(startIndexInSearchedText-1) +
                            (if (selectionSize > 0)
                                then "["
                                      + searchedText.span(startIndexInSearchedText, endIndexInSearchedText-1)
                                      + "]"
                                      + searchedText.spanFrom(endIndexInSearchedText)
                                else "^" + searchedText.spanFrom(startIndexInSearchedText))``
                       ";
        };
    }

    test shared void justBeforeDot()
            => test {
                searchedText = "    aClass.method();";
                startIndexInSearchedText = 10;
                endIndexInSearchedText = 10;
                expectedNode = [`Tree.BaseMemberExpression`, "aClass"];
            };

    test shared void variableStart()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 4;
        endIndexInSearchedText = 4;
        expectedNode = [`Tree.BaseMemberExpression`, "aClass"];
    };

    test shared void insideReference()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 7;
        endIndexInSearchedText = 8;
        expectedNode = [`Tree.BaseMemberExpression`, "aClass"];
    };
    
    test shared void caretWsBeforeStatement()
            => test {
        searchedText = "void oneline() {    print(123);    }";
        startIndexInSearchedText = 17;
        endIndexInSearchedText = 17;
        expectedNode = [`Tree.Block`, "{    print(123);    }"];
    };
    
    test shared void caretWsAfterStatement()
            => test {
        searchedText = "void oneline() {    print(123);    }";
        startIndexInSearchedText = 33;
        endIndexInSearchedText = 33;
        expectedNode = [`Tree.Block`, "{    print(123);    }"];
    };
}