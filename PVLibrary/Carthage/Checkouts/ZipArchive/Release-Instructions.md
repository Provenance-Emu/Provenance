The following steps should be taking by project maintainers if they create a new release.

1. Create a new release and tag for the release.

    - Tags should be in the form of vMajor.Minor.Revision

    - Release names should be  more human readable: Version Major.Minor.Revision

2. Update the podspec

3. Push the pod to the trunk 

    - *pod trunk push SSZipArchive.podspec*
    
4. Create a Carthage framework archive

    - *carthage build --no-skip-current*
    - *carthage archive ZipArchive*
    
5. Attach archive to the release created in step 1.
