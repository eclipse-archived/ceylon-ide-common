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
    resourcesRootForPackage,
    findInLines
}

Directory resourcesRoot = resourcesRootForPackage(`package`);

shared class NodesTests() {
    [String*] loadLines(String fileName) {
        assert(is File file=resourcesRoot.childResource(fileName));
        return lines(file);
    }

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
            then if (exists end=node?.endIndex?.intValue())
                    then contents.span(start, end-1)
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

    test shared void methodCall_longValueName_longMemberName_caretBeforeDot()
            => test {
                searchedText = "    aClass.method();";
                startIndexInSearchedText = 10;
                endIndexInSearchedText = 10;
                expectedNode = [`Tree.BaseMemberExpression`, "aClass"];
            };

    test shared void methodCall_longValueName_longMemberName_caretAtValueStart()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 4;
        endIndexInSearchedText = 4;
        expectedNode = [`Tree.BaseMemberExpression`, "aClass"];
    };

    test shared void methodCall_longValueName_longMemberName_caretInsideValue()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 6;
        endIndexInSearchedText = 6;
        expectedNode = [`Tree.BaseMemberExpression`, "aClass"];
    };

    test shared void methodCall_longValueName_longMemberName_selectionInsideValue()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 7;
        endIndexInSearchedText = 8;
        expectedNode = [`Tree.BaseMemberExpression`, "aClass"];
    };

    test shared void methodCall_longValueName_longMemberName_selectionValue()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 4;
        endIndexInSearchedText = 10;
        expectedNode = [`Tree.BaseMemberExpression`, "aClass"];
    };

    test shared void methodCall_longValueName_longMemberName_selectionValueWithWSBefore()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 2;
        endIndexInSearchedText = 10;
        expectedNode = [`Tree.BaseMemberExpression`, "aClass"];
    };

    test shared void methodCall_longValueName_longMemberName_caretBeforeMemberParameterList()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 17;
        endIndexInSearchedText = 17;
        expectedNode = [`Tree.QualifiedMemberExpression`, "aClass.method"];
    };

    test shared void methodCall_longValueName_longMemberName_caretInsideMemberParameterList()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 18;
        endIndexInSearchedText = 18;
        expectedNode = [`Tree.PositionalArgumentList`, "()"];
    };

    test shared void methodCall_longValueName_longMemberName_caretAtMemberStart()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 11;
        endIndexInSearchedText = 11;
        expectedNode = [`Tree.QualifiedMemberExpression`, "aClass.method"];
    };

    test shared void methodCall_longValueName_longMemberName_caretInsideMember()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 13;
        endIndexInSearchedText = 13;
        expectedNode = [`Tree.QualifiedMemberExpression`, "aClass.method"];
    };

    test shared void methodCall_longValueName_longMemberName_selectionInsideMember()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 13;
        endIndexInSearchedText = 15;
        expectedNode = [`Tree.QualifiedMemberExpression`, "aClass.method"];
    };

    test shared void methodCall_longValueName_longMemberName_selectionMemberWithoutParameterList()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 11;
        endIndexInSearchedText = 17;
        expectedNode = [`Tree.QualifiedMemberExpression`, "aClass.method"];
    };

    test shared void methodCall_longValueName_longMemberName_selectionMemberWithParameterListPart()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 11;
        endIndexInSearchedText = 18;
        expectedNode = [`Tree.InvocationExpression`, "aClass.method()"];
    };

    test shared void methodCall_longValueName_longMemberName_selectionMemberWithParameterList()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 11;
        endIndexInSearchedText = 19;
        expectedNode = [`Tree.InvocationExpression`, "aClass.method()"];
    };

    test shared void methodCall_longValueName_longMemberName_selectionDotOnly()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 10;
        endIndexInSearchedText = 11;
        expectedNode = [`Tree.QualifiedMemberExpression`, "aClass.method"];
    };

    test shared void methodCall_longValueName_longMemberName_selectionValueAndMemberParts()
            => test {
        searchedText = "    aClass.method();";
        startIndexInSearchedText = 8;
        endIndexInSearchedText = 14;
        expectedNode = [`Tree.QualifiedMemberExpression`, "aClass.method"];
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