+++
categories = ["y"]
date = "2018-03-10T14:58:41+11:00"
tags = ["GitLab"]
title = "GitLab: Disable/Enable Local Authentication via CLI"
aliases = [
	"/2017/04/07/vmware-nsx-v-manager-central-cli-via-rest-api/",
	"/post/vmware-nsx-v-manager-central-cli-via-rest-api/"
]

+++
I recently assisted with enabling SAML federation for a production GitLab instance. Surprisingly, the only documented method to enable or disable local authentication was via the administration user interface. If SAML federation stops working, and you have disabled local authentication, you may need a means of re-enabling local authentication.

There are some GitHub gists and blog posts out there that discuss the approach to do so. However, these were written for an older version of GitHub and it seems the database schema with respect to application settings has since changed. The following procedure worked for me.

It should be noted there is a separate configuration setting for enabling/disabling local authentication for the Git service: `password_authentication_enabled_for_git`.

# Disable Local Authentication via CLI

1. Execute the following command to open a GitLab console.

```
sudo gitlab-rails console
```

2. Wait for the 'irb' prompt to appear, and then execute the following command.

```
ApplicationSetting.last.update_attributes(password_authentication_enabled_for_web: false)
```

3. Execute the following command to restart GitLab.

```
sudo gitlab-ctl restart
```

# Enable Local Authentication via CLI

1. Execute the following command to open a GitLab console.

```
sudo gitlab-rails console
```

2. Wait for the 'irb' prompt to appear, and then execute the following command.

```
ApplicationSetting.last.update_attributes(password_authentication_enabled_for_web: true)
```

3. Execute the following command to restart GitLab.

```
sudo gitlab-ctl restart
```
