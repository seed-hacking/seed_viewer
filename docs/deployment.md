# SEED Viewer Deployment Notes

Traditionally, all SEED CGI scripts were deployed into a subdirectory FIG/CGI of the
FIGdisk. 

With the change to the split data/deployment release engineering, we will 
deploy CGI code instead into a cgi-bin directory that sits aside the bin directory
in both the development container and the deployment directory.

CGI sources will be located in the cgi-scripts directory in the source modules.



## Administration issues

### Creating logins

```
user_add -firstname Robert -lastname Olson -login olsonadmin -email olson@mcs.anl.gov
user_add_login_right -application SeedViewer -login olsonadmin -grant
```