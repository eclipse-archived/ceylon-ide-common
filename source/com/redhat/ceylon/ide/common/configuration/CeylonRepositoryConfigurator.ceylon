import ceylon.collection {
    ArrayList,
    MutableList
}

import com.redhat.ceylon.ide.common.model {
    CeylonProjectConfig
}

import java.lang {
    IntArray,
    ObjectArray,
    JString=String,
    Types
}

shared abstract class CeylonRepositoryConfigurator() {

    value projectLocalRepos = ArrayList<String>();
    value globalLookupRepos = ArrayList<String>();
    value projectRemoteRepos = ArrayList<String>();
    value otherRemoteRepos = ArrayList<String>();

    shared void addGlobalLookupRepo(String repo) => globalLookupRepos.add(repo);
    shared void addOtherRemoteRepo(String repo) => otherRemoteRepos.add(repo);

    shared Boolean isFixedRepoIndex(Integer index) {
        if (!globalLookupRepos.empty && 
            index>=projectLocalRepos.size && 
                index < projectLocalRepos.size+globalLookupRepos.size) { 
            return true; 
        }
        if (!otherRemoteRepos.empty && 
            index >= projectLocalRepos.size+globalLookupRepos.size+projectRemoteRepos.size && 
            index < projectLocalRepos.size+globalLookupRepos.size+projectRemoteRepos.size+otherRemoteRepos.size) { 
            return true; 
        }
        return false;
    }

    shared void updateButtonState() {
        updateRemoveRepoButtonState();
        updateUpDownButtonState();
    }

    shared formal IntArray selection;

    shared formal void enableRemoveButton(Boolean enable);
    shared formal void enableUpButton(Boolean enable);
    shared formal void enableDownButton(Boolean enable);
    shared formal String removeRepositoryFromList(Integer index);
    shared formal void addRepositoryToList(Integer index, String repo);
    shared formal void addAllRepositoriesToList(ObjectArray<JString> repos);

    void addRepositoryListToList({String*} newRepos, MutableList<String> repos) {
        repos.clear();
        repos.addAll(newRepos);
        addAllRepositoriesToList(ObjectArray.with(repos.map(Types.nativeString)));
    }
    
    shared void addExternalRepo(String repo) => addProjectRepo(repo, 0, true);

    shared void addRemoteRepo(String repo) {
        Integer index = projectLocalRepos.size + globalLookupRepos.size + projectRemoteRepos.size;
        addProjectRepo(repo, index, false);
    }

    shared void addAetherRepo(String repo) {
        value index = projectLocalRepos.size + globalLookupRepos.size + projectRemoteRepos.size;
        addProjectRepo(repo.empty then "maven" else "maven:" + repo, index, false);
    }

    shared void applyToConfiguration(CeylonProjectConfig config) {
        config.projectLocalRepos = projectLocalRepos.sequence();
        config.projectRemoteRepos = projectRemoteRepos.sequence();
    }

    shared void loadFromConfiguration(CeylonProjectConfig config) {
        addRepositoryListToList(config.projectLocalRepos, projectLocalRepos);
        addRepositoryListToList(config.globalLookupRepos, globalLookupRepos);
        addRepositoryListToList(config.projectRemoteRepos, projectRemoteRepos);
        addRepositoryListToList(config.otherRemoteRepos, otherRemoteRepos);
    }

    shared Boolean isRepoConfigurationModified(CeylonProjectConfig config) 
            => projectLocalRepos!=config.projectLocalRepos 
            || projectRemoteRepos!=config.projectRemoteRepos;

    shared void removeSelectedRepo() {
        value sortedSelection = sort(selection.iterable);

        for (i in 0:sortedSelection.size) {
            value index = sortedSelection[i];

            if (exists index, !isFixedRepoIndex(index)) {
                String repo = removeRepositoryFromList(index);
                projectLocalRepos.remove(repo);
                projectRemoteRepos.remove(repo);
            }
        }
        updateButtonState();
    }

    shared void moveSelectedReposUp() {
        if (exists index = selection.iterable.first) {
            String repo = removeRepositoryFromList(index);

            if (index>0 && index<=projectLocalRepos.size) {
                projectLocalRepos.delete(index);
                addProjectRepo(repo, index - 1, true);
            }
            if (index == projectLocalRepos.size+globalLookupRepos.size) {
                projectRemoteRepos.remove(repo);
                addProjectRepo(repo, projectLocalRepos.size, true);
            }
            if (index > projectLocalRepos.size+globalLookupRepos.size) {
                projectRemoteRepos.remove(repo);
                addProjectRepo(repo, index - 1, false);
            }
        }
    }

    shared void moveSelectedReposDown() {
        if (exists index = selection.iterable.first) {
            String repo = removeRepositoryFromList(index);

            if (index < projectLocalRepos.size-1 && !projectLocalRepos.empty) {
                projectLocalRepos.remove(repo);
                addProjectRepo(repo, index + 1, true);
            }
            if (index == projectLocalRepos.size-1 && !projectLocalRepos.empty) {
                projectLocalRepos.remove(repo);
                addProjectRepo(repo, projectLocalRepos.size + globalLookupRepos.size, false);
            }
            if (index >= projectLocalRepos.size+globalLookupRepos.size  && 
                index < projectLocalRepos.size+globalLookupRepos.size+projectRemoteRepos.size-1) {
                projectRemoteRepos.remove(repo);
                addProjectRepo(repo, index + 1, false);
            }
        }
    }

    void updateRemoveRepoButtonState() {
        for (index in selection.iterable) {
            if (!isFixedRepoIndex(index)) {
                enableRemoveButton(true);
                return;
            }
        }
        enableRemoveButton(false);
    }

    void updateUpDownButtonState() {
        variable Boolean isUpEnabled = false;
        variable Boolean isDownEnabled = false;
        value selectionIndices = selection.iterable;

        if (selectionIndices.size == 1) {
            if (exists index = selection.iterable.first) {
                if (index>0 && !isFixedRepoIndex(index)) {
                    isUpEnabled = true;
                }
                value maxIndex 
                        = projectLocalRepos.size 
                        + globalLookupRepos.size 
                        + projectRemoteRepos.size - 1;
                if (index<maxIndex && !isFixedRepoIndex(index)) {
                    isDownEnabled = true;
                }
            }
        }
        enableUpButton(isUpEnabled);
        enableDownButton(isDownEnabled);
    }

    void addProjectRepo(String repo, Integer index, Boolean isLocalRepo) {
        if (isLocalRepo && repo in projectLocalRepos) {
            return;
        }
        if (!isLocalRepo && repo in projectRemoteRepos) {
            return;
        }
        if (isLocalRepo) {
            projectLocalRepos.insert(index, repo);
        } else {
            value remoteIndex 
                    = index 
                    - projectLocalRepos.size 
                    - globalLookupRepos.size;
            projectRemoteRepos.insert(remoteIndex, repo);
        }
        addRepositoryToList(index, repo);
        updateButtonState();
    }
}
