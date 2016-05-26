shared interface JavaModelServicesConsumer<JavaClassRoot> {
    shared JavaModelServices<JavaClassRoot> javaModelServices =>
            platformServices.javaModel<JavaClassRoot>();
}