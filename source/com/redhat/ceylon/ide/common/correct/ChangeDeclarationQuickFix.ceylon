import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    ReplaceEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}

import org.antlr.runtime {
    CommonToken
}

shared object changeDeclarationQuickFix {

    shared void addChangeDeclarationProposal(QuickFixData data) {
        assert (is Tree.Declaration decNode = data.node);
        if (exists token = decNode.mainToken) {
            assert (is CommonToken token);

            String keyword;
            switch (decNode)
            case (is Tree.AnyClass) {
                keyword = "interface";
            }
            case (is Tree.AnyMethod) {
                if (token.type==CeylonLexer.\iVOID_MODIFIER) {
                    return;
                }
                keyword = "value";
            }
            else {
                return;
            }
                        
            value change 
                    = platformServices.createTextChange {
                name = "Change Declaration";
                input = data.phasedUnit;
            };
            change.addEdit(ReplaceEdit {
                start = token.startIndex;
                length = token.text.size;
                text = keyword;
            });
            data.addQuickFix {
                desc = "Change declaration to '``keyword``'";
                change = change;
                selection = DefaultRegion {
                    start = token.startIndex;
                    length = keyword.size;
                };
            };
        }
    }
}
