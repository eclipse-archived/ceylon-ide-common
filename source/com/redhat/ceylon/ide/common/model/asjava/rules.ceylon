import com.redhat.ceylon.model.typechecker.model {
    Class,
    Declaration,
    ClassOrInterface
}

shared class JavaVisibility of packagePrivate | public | protected | private {
    shared new packagePrivate {}
    shared new public {}
    shared new protected {}
    shared new private {}
}

shared object rules {
    shared object classMirror {
        shared object constructors {
            shared Boolean addHiddenThisParameter(Class cls)
                => ! cls.static && cls.classMember;
            shared JavaVisibility visibility(Class cls)
                => if (!cls.shared) then JavaVisibility.packagePrivate
                else if (cls.classMember) then JavaVisibility.protected
                else JavaVisibility.public;
        }
    }
    shared object annotations {
            shared Boolean addTheCeylonAnnotation(Declaration decl)
                => decl.toplevel || decl is ClassOrInterface;
    }
}

