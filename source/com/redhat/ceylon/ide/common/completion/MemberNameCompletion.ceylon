import ceylon.collection {
    MutableList,
    HashSet
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Visitor,
    Tree
}

shared interface MemberNameCompletion<IdeComponent, CompletionComponent> {
    
     shared void addMemberNameProposal(Integer offset, String prefix, Node node, List <CompletionComponent> result){
        value proposals = HashSet<String>();

        // TODO
    }
}