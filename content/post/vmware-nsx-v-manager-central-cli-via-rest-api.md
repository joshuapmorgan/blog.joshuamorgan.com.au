+++
date = "2017-04-07T13:33:00+10:00"
tags = ["NSX"]
title = "VMware NSX-v Manager: Central CLI via REST API"
aliases = [
	"/2017/04/07/vmware-nsx-v-manager-central-cli-via-rest-api/",
	"/post/vmware-nsx-v-manager-central-cli-via-rest-api/"
]
+++

For the project I am currently working on, I am using automated testing to validate the solution. With respect to VMware NSX-v, I am utilising the Central CLI as the NSX-v REST API does not appear to include any resources that provide operational state (you can validate ‘traffic light’ status of an NSX Edge, for example, but you cannot check the state of BGP neighbors, as another example). Pretty disappointing. Instead, I am using the Central CLI feature that allows execution of CLI commands against the NSX-v Manager, controllers, or edges via the REST API. I then use TextFSM to parse the unstructured text (the output of the various show commands) into structured data that I can then use within my script’s logic.

These automated testing scripts were written against VMware NSX-v 6.2.2. However, for this project, I have deployed VMware NSX-v 6.2.4. I was receiving HTTP 406 errors when trying to execute Central CLI commands via the REST API. After consideration of the response text (which is vague and not immediately obvious), it seems that VMware has changed the REST API somewhere between 6.2.2 and 6.2.4 to require that the ‘Accept’ HTTP header be configured with ‘text/plain’ as its MIME type. This change has not been documented, as best I can tell, within their API Guide.

PowerNSX was updated per commit [e2fcbe5](https://github.com/vmware/powernsx/commit/e2fcbe5a8855c8605fd86ea0d0e2c5df8b302187)/pull request #[177](https://github.com/vmware/powernsx/pull/177) to now include this HTTP header when using the Invoke-NsxCli cmdlet.
