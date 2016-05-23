import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.settings {
    CompletionOptions
}
import java.util.regex {
    Pattern
}
import org.antlr.runtime {
    CommonToken
}
import java.util {
    JList=List
}

shared interface CompletionContext satisfies LocalAnalysisResult {
    shared formal ProposalsHolder proposals;
    shared formal CompletionOptions options;
    shared formal List<Pattern> proposalFilters; // TODO put in options?
    shared formal actual JList<CommonToken> tokens;
}

"A store for native completion proposals, usually baked by an ArrayList of:
 
 * `ICompletionProposal` on Eclipse
 * `LookupElement` on IntelliJ
 "
shared interface ProposalsHolder {
    shared formal Integer size;
    shared Boolean empty => size == 0;
}