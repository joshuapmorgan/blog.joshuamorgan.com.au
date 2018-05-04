+++
categories = ["y"]
date = "2018-05-05T09:47:43+10:00"
tags = ["AWS", "Go", "Golang", "STS", "Forgerock", "SAML"]
title = "My first real foray into Go: forgerock-aws-sts"
aliases = [
	"/2018/05/05/golang-aws-sts-forgerock-idp/",
	"/post/golang-aws-sts-forgerock-idp/"
]

+++

At the end of 2017, I ordered and received a copy of 'The Go Programming Language' by Alan A. A. Donovan and Brian W. Kernighan. The book is excellent in describing Go in detail and by example, yet in a manner terse enough that it is able to fit in 380 pages.

In 2017, for a work requirement, I had written a quick and dirty Python script to authenticate to a Forgerock based IdP, and use the resultant SAML assertion to obtain ephemeral API keys for AWS via its Security Token Service (STS).

After I had gotten three quarters of the way through reading 'The Go Programming Language', I decided to get my hands dirty and start writing Go. My first project: forgerock-aws-sts; a Go based replacement for my Python script, albeit relatively polished.

I've commited the code to Github: https://github.com/joshuapmorgan/forgerock-aws-sts/. I'm not sure how useful the utility is in reality, I'm not aware of how many organisations federate their AWS accounts with Forgerock as an IdP using SAML.

I've not thoroughly tested on Linux/Windows, so if there are any issues please raise a Github issue.
