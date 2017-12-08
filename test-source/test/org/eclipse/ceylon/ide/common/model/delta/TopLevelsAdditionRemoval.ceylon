import ceylon.test {
    test
}

import org.eclipse.ceylon.ide.common.model.delta {
    removed,
    TopLevelDeclarationAdded,
    visibleOutside,
    invisibleOutside
}

import test.org.eclipse.ceylon.ide.common.model.delta {
    comparePhasedUnits,
    RegularCompilationUnitDeltaMockup,
    TopLevelDeclarationDeltaMockup
}

test void addTopLevel() {
    comparePhasedUnits {
        path = "dir/test.ceylon";
        oldContents =
                "
                 shared void test() {}
                 ";
        newContents =
                "
                 shared void test() {}
                 shared void test2() {}
                 void hidden() {}
                 ";
        expectedDelta =
            RegularCompilationUnitDeltaMockup {
                changedElementString = "Unit[test.ceylon]";
                changes = { TopLevelDeclarationAdded("test2", visibleOutside),
                            TopLevelDeclarationAdded("hidden", invisibleOutside)};
                childrenDeltas = {};
            };
    };
}

test void removeTopLevel() {
    comparePhasedUnits {
        path = "dir/test.ceylon";
        oldContents =
                "
                 shared void test() {}
                 void hidden() {}
                 ";
        newContents =
                "
                 ";
        expectedDelta =
                RegularCompilationUnitDeltaMockup {
            changedElementString = "Unit[test.ceylon]";
            changes = {};
            childrenDeltas = {
                TopLevelDeclarationDeltaMockup {
                    changedElementString = "Function[test]";
                    changes = { removed };
                },
                TopLevelDeclarationDeltaMockup {
                    changedElementString = "Function[hidden]";
                    changes = { removed };
                }
            };
        };
    };
}

test void changeToplevelName() {
    comparePhasedUnits {
        path = "dir/test.ceylon";
        oldContents =
                "
                 shared void test() {}
                 ";
        newContents =
                "
                 shared void testChanged() {}
                 ";
        expectedDelta =
                RegularCompilationUnitDeltaMockup {
            changedElementString = "Unit[test.ceylon]";
            changes = { TopLevelDeclarationAdded("testChanged", visibleOutside) };
            childrenDeltas = {
                TopLevelDeclarationDeltaMockup {
                    changedElementString = "Function[test]";
                    changes = { removed };
                    childrenDeltas = {};
                }
            };
        };
    };
}
