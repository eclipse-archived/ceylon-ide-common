import ceylon.collection {
    HashMap
}

shared abstract class CeylonProjects<IdeArtifact>()
        given IdeArtifact satisfies Object {
    value projectMap = HashMap<IdeArtifact, CeylonProject<IdeArtifact>>();
    shared {CeylonProject<IdeArtifact>*} ceylonProjects => projectMap.items;
    
    shared CeylonProject<IdeArtifact> getProject(IdeArtifact ideArtifact) {
        value searchedProject = projectMap[ideArtifact];
        if (exists searchedProject) {
            return searchedProject;
        } else {
            value theNewProject = newIdeArtifact(ideArtifact);
            projectMap.put(ideArtifact, theNewProject);
            return theNewProject;
            
        }
    }
    
    shared formal CeylonProject<IdeArtifact> newIdeArtifact(IdeArtifact ideArtifact);
    shared void removeProject(IdeArtifact ideArtifact)
            => projectMap.remove(ideArtifact);
    shared void addProject(IdeArtifact ideArtifact)
            => projectMap.put(ideArtifact, newIdeArtifact(ideArtifact));
    shared void clearProjects()
            => projectMap.clear();
}