import com.redhat.ceylon.ide.common.util {
    Indents
}

deprecated("Use [[CommonDocument]] instead.")
shared interface IndentsServicesConsumer<Document> {
    shared Indents<Document> indents => platformServices.indents<Document>();
}
