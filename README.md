[![Deploy to Bluemix](https://bluemix.net/deploy/button_x2.png)](https://bluemix.net/deploy?repository=https://github.com/joshisa/drupalstart)
###Drupal::Self-Assembly
<i>noun</i>
 1. The spontaneous formation of a body in a medium containing the appropriate components
 2. The rapid instantiation of a [Drupal](https://www.drupal.org/ "Drupal") 7.x Deployment Instance on IBM Bluemix containing the appropriate components.

An opinionated one-click self-assembling deployment of the Drupal platform for content management software onto a CloudFoundry platform.  

#### Why?
Open source projects are awesome. PaaS CloudFoundry enabling of self-hosted open source application platforms is messy.  Making a mashup between cool opensource and cloud-enabling tweaks that makes deployment feel sweet and simple is "hard to do".  Legal review burdens aside, the level of ongoing maintenance effort is directly proportional to the number of tweaks in the mashup.  So, keeping a repository concise and abbreviated in content is smart.  My objective with this repo experiment is to facilitate consistent, rapid Piwik deploys on IBM Bluemix with minimal deployment friction using the fewest files possible.

#### Getting Started  (Pre-requisite: [CF CLI](https://github.com/cloudfoundry/cli/releases "CF CLI"))
- Pre-Create a PostgreSQL deployment within Compose.io
  1.  Create a compose.io account
  2.  Create a new PostgreSQL deployment.  The name is per your discretion.
  3.  Verification Point:  After deployment, one default DB is created named "compose".  This deployment assumes the presence of this DB with that name.  If you want to create and use a different db name, then modifications will need to be done to the pipeline.yml file within the .bluemix folder to change the default name.
  4.  Create a new **unbound** Bluemix Compose PostgreSQL service named **drupaldb**.  Populate the service tile with details from your Compose.io deployment.  You will need 3 things:  username which defaults to "admin", password and the host:port string
  5.  Verification Point:  Your Bluemix dashboard should now show a drupaldb named PostGreSQL service.
- Click the Deploy Button Above.  Verification Point:  Await success of all 4 steps on the deploy page.
 
- [Optional] Site settings for Drupal 7 are persisted in a file named **settings.php** that we will need to pull down and persist back into the repository.  As an application running on a PaaS, the app's local file storage is ephemeral.  Without persistence, any restart or crash/restart sequence will cause your Piwik application to revert back to the web installer sequence.
- Within the terminal, browse to the root dir of your local cloned IBM DevOps project repo (e.g.  git clone ::url to IBM DevOps project::) and execute a command similar to:
```
$ cf files <replace_me_with_app_name> /app/fetchConfig.sh | sed -e '1,3d' > fetchConfig.sh
$ chmod +x fetchConfig.sh
$ ./fetchConfig.sh
```
- This should pull down a helper bash script named fetchConfig.sh.  Your app's name will already be populated :-)  This script helps you (repeatedly) persist the config file in the expected location.  It also will **DEACTIVATE** some of the Example Plugins that are deemed a performance+security vulnerability.
- Perform a git add, git commit and git push to persist the config.ini.php within the IBM DevOps repository. For example,
```git add -A```
```git commit -m "Persisting the installer wizard generated config.ini.php"```
```git push```
- With this git commit, your IBM DevOps pipeline will retrigger and re-deploy Drupal 7.  In a few short minutes, your Drupal application will be ready for you to use.

#### How is this better than Docker?
Better is not the right question.  Sometimes a cool project may not have a high-quality Dockerfile image available yet. I wanted to experiment with how to create a Bluemix instant deploy repo via pure DevOps scripting and git concepts (submodules).  Sometimes you may want to learn more about how specific runtimes and buildpacks behave within a PaaS - so what better way than to see in detail how complex apps and platforms are assembled for PaaS CloudFoundry cloud deployment.  Sometimes you feel more comfortable understanding (fill in your favorite runtime language - PHP, Python, Node.js, ...) than Docker CLI.  Sometimes Docker is the way better approach to go, but you like doing things the hard way ;-)

#### How does it work?
The magic is in the .bluemix/pipeline.yml.  A build script is embedded which precisely defines the steps required to PaaS CloudFoundry enable the opensource application.  The script pulls code from various locations, applies tweaks and cleans itself up into a deployable asset.  Using IBM DevOps services, you may download the built asset by accessing the builder stage and "downloading all artifacts" (which can then be tweaked further and deployed manually using the CF CLI) or simply let the DevOps pipeline continue to do the assembly and deploy effort for you.  The former is useful for devs looking to innvoate and expand capabilities of the open source project (For example: adding cognitive computing interactions from something like IBM Watson) and the latter is for folks simply desiring a rapid turnkey deployment of the opensource project for end-use.

#### Why didn't you use packaging technologies like Composer, Bundler, ...?
In many cases, the deploy in fact is using these packaging technologies to help gather app platform dependencies. Complementary to that behavior, this repository automates the organization and customization of files PRIOR to dependency inspection and installation.  For example, customization tweaks that make the web installer process smarter in self-populating bound service credentials, setting up a hardened deploy with a better security and performance profile, new feature tweaks that include service client sdks such as Twiliio, etc ...  

#### Installing additional modules
If you want to add additional Drupal modules not included within this repo,  download your module of interest from the [Drupal Modules](https://www.drupal.org/project/project_module?f%5B0%5D=&f%5B1%5D=&f%5B2%5D=&f%5B3%5D=drupal_core%3A103&f%5B4%5D=sm_field_project_type%3Afull&text=&solrsort=iss_project_release_usage+desc&op=Search "Drupal 7.x Modules").  Extract the zip contents into the folder **/bluezone/configtweaks/modules** . This would result in something like ./bluezone/configtweaks/modules/myawesomemodule .  You are free to add as many module folders as you'd like within this parent **modules** dir.  The scripts will loop through and place them within the correct location for you for your site.  The process for themes and libraries follows the same logic.
- Perform a git add, git commit and git push to persist the newly added modules within the IBM DevOps repository. For example,
```git add -A```
```git commit -m "Added myawesomemodule to my Drupal deploy"```
```git push```
- With this git commit, your IBM DevOps pipeline will retrigger and re-deploy Piwik.  You will then need to access the modules section of Drupal and **Enable** the myawesomemodule.

#### Reference
[Deploy a Drupal Application on Bluemix](https://developer.ibm.com/bluemix/2014/02/17/deploy-drupal-application-ibm-bluemix/)
