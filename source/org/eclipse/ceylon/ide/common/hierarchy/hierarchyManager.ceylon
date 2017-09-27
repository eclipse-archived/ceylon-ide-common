import org.eclipse.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    TypeDeclaration,
    ModelUtil,
    ClassOrInterface,
    Type
}
import java.util {
    List
}

shared object hierarchyManager {

    shared {Declaration*} findSubtypes(Declaration model, {PhasedUnit*} phasedUnits) {
        if (model.classOrInterfaceMember,
            model.formal || model.default) {

            return {
                for (unit in phasedUnits)
                for (declaration in unit.declarations)
                if (declaration.classOrInterfaceMember, declaration.actual)
                if (declaration.refines(model),
                    declaration != model,
                    directlyRefines(declaration, model))
                declaration
            };
        }

        return [];
    }

    shared {Declaration*} findSupertypes(Declaration model) {
        if (is ClassOrInterface container = model.container,
            model.actual) {

            List<Type>? signature = ModelUtil.getSignature(model);
            Boolean variadic = ModelUtil.isVariadic(model);
            return {
                for (supertype in container.supertypeDeclarations)
                if (exists declaration
                        = supertype.getDirectMember(model.name,
                                signature, variadic, true),
                    declaration.default || declaration.formal,
                    model.refines(declaration),
                    directlyRefines(model, declaration))
                declaration
            };
        }

        return [];
    }

    Boolean directlyRefines(Declaration subtype, Declaration supertype) {
        assert (is TypeDeclaration subtypeScope = subtype.container,
                is TypeDeclaration supertypeScope = supertype.container);
        value interveningRefinements
                = ModelUtil.getInterveningRefinements(subtype,
                        supertype.refinedDeclaration,
                        subtypeScope, supertypeScope);
        interveningRefinements.remove(supertype);
        return interveningRefinements.empty;
    }
}