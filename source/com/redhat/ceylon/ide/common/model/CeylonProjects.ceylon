import ceylon.collection {
    HashMap
}

import java.util.concurrent.locks { ReentrantReadWriteLock,
    Lock }
import java.lang {
    InterruptedException
}

shared abstract class CeylonProjects<IdeArtifact>()
        given IdeArtifact satisfies Object {
    value projectMap = HashMap<IdeArtifact, CeylonProject<IdeArtifact>>();

    value lock = ReentrantReadWriteLock(true);
    T withLocking<T=Anything>(Boolean write, T do(), T() interrupted) {
        Lock l = if (write) then lock.writeLock() else lock.readLock();
        l.lockInterruptibly();
        try {
            return do();
        } catch(InterruptedException e) {
            return interrupted();
        }finally {
            l.unlock();
        }
    }

    shared formal CeylonProject<IdeArtifact> newIdeArtifact(IdeArtifact ideArtifact);

    shared {CeylonProject<IdeArtifact>*} ceylonProjects
        => withLocking {
            write=false;
            do() => projectMap.items.sequence();
            interrupted() => {};
        };


    shared CeylonProject<IdeArtifact>? getProject(IdeArtifact? ideArtifact)
        => withLocking {
            write=false;
            do() => if (exists ideArtifact) then projectMap[ideArtifact] else null;
            interrupted() => null;
        };

    shared Boolean removeProject(IdeArtifact ideArtifact)
        => withLocking {
            write=true;
            do() => projectMap.remove(ideArtifact) exists;
            interrupted() => false;
        };

    shared Boolean addProject(IdeArtifact ideArtifact)
        => withLocking {
            write=true;
            function do() {
                 if (projectMap[ideArtifact] exists) {
                     return false;
                 } else {
                     projectMap.put(ideArtifact, newIdeArtifact(ideArtifact));
                     return true;
                 }
            }
            interrupted() => false;
        };

    shared void clearProjects()
        => withLocking {
            write=true;
            do() => projectMap.clear();
            interrupted() => null;
        };

}