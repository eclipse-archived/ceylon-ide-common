import com.redhat.ceylon.ide.common.correct {
    ImportProposals
}


shared interface ImportProposalServicesConsumer<File, CompletionProposal, Document, InsertEdit, TextEdit, TextChange> {
    shared ImportProposals<File, CompletionProposal, Document, InsertEdit, TextEdit, TextChange> importProposals =>
            platformServices.importProposals<File, CompletionProposal, Document, InsertEdit, TextEdit, TextChange>();
}