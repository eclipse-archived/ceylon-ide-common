import com.redhat.ceylon.langtools.tools.javac.code {
    Flags
}
import com.redhat.ceylon.model.loader.mirror {
    AccessibleMirror
}

interface ModelBasedAccessibleMirror 
        satisfies ModelBasedMirror &
        AccessibleMirror {
    shared formal Integer flags;

    defaultAccess => flags.and(Flags.accessFlags) == 0;
    protected => flags.and(Flags.protected) > 0;
    public => flags.and(Flags.public) > 0;
}