shared abstract class ProposalKind()
        of generic | keyword {}

shared object generic extends ProposalKind() {}
shared object keyword extends ProposalKind() {}
