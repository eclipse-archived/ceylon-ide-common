import org.eclipse.ceylon.ide.common.util {
    synchronize
}

shared interface NewNameRefactoring {
    shared variable formal String? internalNewName;
    shared default String newName
            => synchronize {
        on = this;
        function do() {
            if (exists n = internalNewName) {
                return n;
            } else {
                internalNewName = initialNewName;
                assert (exists n = internalNewName);
                return n;
            }
        }
    };
    assign newName {
        synchronize {
            on = this;
            void do() {
                internalNewName = newName;
            }
        };
    }
    shared formal String initialNewName;
    shared formal Boolean forceWizardMode;
}

