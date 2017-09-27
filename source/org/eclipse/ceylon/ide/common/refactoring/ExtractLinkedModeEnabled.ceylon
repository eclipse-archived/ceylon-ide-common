

shared class DefaultRegion(start, length=0) {
    shared Integer start;
    shared Integer length;
    shared Integer end => start + length;

    string => "[``start``-``length``]";
}

shared interface ExtractLinkedModeEnabled<Region=DefaultRegion> {
    shared formal variable Region? typeRegion;
    shared formal variable Region? decRegion;
    shared formal variable Region? refRegion;

    shared formal Region newRegion(Integer start, Integer length);

    shared formal [String+] nameProposals;
    
}
