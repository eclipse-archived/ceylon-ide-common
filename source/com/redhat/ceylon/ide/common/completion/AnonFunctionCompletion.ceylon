import com.redhat.ceylon.model.typechecker.model {
    Unit,
    Type
}
import ceylon.collection {
    MutableList
}

shared interface AnonFunctionCompletion<CompletionResult> {
    shared formal CompletionResult newAnonFunctionProposal(Integer offset, Type? requiredType,
        Unit unit, String text, String header, Boolean isVoid,
        Integer selectionStart, Integer selectionLength);
    
    shared void addAnonFunctionProposal(Integer offset, Type? requiredType, MutableList<CompletionResult> result, Unit unit){
        value text = anonFunctionHeader(requiredType, unit);
        value funtext = text + " => nothing";
        
        result.add(newAnonFunctionProposal(offset, requiredType, unit, funtext,
            text, false, offset + (funtext.firstInclusion("nothing") else 0), 7));
        
        if (unit.getCallableReturnType(requiredType).anything){
            value voidtext = "void " + text + " {}";
            result.add(newAnonFunctionProposal(offset, requiredType, unit, voidtext,
                    text, true, offset + funtext.size - 1, 0));
        }
    }

}