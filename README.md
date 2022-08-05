# Detect Action

Integration with Synopsys Detect into GitHub action workflows.

Configure the action to run Detect.

# Set Up Job

Once you have setup a GitHub Workflow with event triggers, you will need to create a _job_ in which the _Detect Action_ will run.  
Your job will look something like this if all configuration options are used:  

## Examples

### Latest code

```yaml
name: Synopsys Detect scan for latest code
on:
  push:
    branches:    
      - 'main'
jobs:
  security:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Run Synopsys Detect
      uses: fnxpt/blackduck-action@main
      with:
          hubURL: ${{ secrets.BLACKDUCK_URL }}
          hubToken: ${{ secrets.BLACKDUCK_TOKEN }}
          projectType: maven
          projectName: example
```

### Released versions

```yaml
name: Synopsys Detect scan for released code
on:
  push:
    tags:
      - '*'
jobs:
    security:
        runs-on: ubuntu-latest
        steps:
        - uses: actions/checkout@v2
        - name: Get the version
          id: get_version
          run: echo ::set-output name=VERSION::${GITHUB_REF#refs/tags/}
        - name: Run Synopsys Detect
          uses: fnxpt/blackduck-action@main
          with:
            hubURL: ${{ secrets.BLACKDUCK_URL }}
            hubToken: ${{ secrets.BLACKDUCK_TOKEN }}
            projectType: maven
            projectName: example
            version: ${{ steps.get_version.outputs.VERSION }}
```

