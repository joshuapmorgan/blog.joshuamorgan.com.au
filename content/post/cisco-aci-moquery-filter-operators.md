+++
date = "2016-09-11T11:58:00+10:00"
tags = ["ACI"]
title = "cisco aci moquery filter operators"
aliases = [
	"/2016/09/11/cisco-aci-moquery-filter-operators/",
	"/post/cisco-aci-moquery-filter-operators/"
]
+++

moquery is a command line utility that ships with the Cisco APIC and iNX-OS (leaf/spine switch operating system). moquery allows querying of the Management Information Tree (MIT) from the command line; it’s also known as the command line cousin to Visore.

The following are the operators that can be used as part of the filter argument. This doesn’t appear to be documented anywhere, so I had to consult the source code (/controller/ishell/insieme/rest/queryfilter.py).

queryfilter.py translates the moquery operator (left column) to its corresponding REST API operator (right column), which are documented here: http://www.cisco.com/c/en/us/td/docs/switches/datacenter/aci/apic/sw/1-x/api/rest/b_APIC_RESTful_API_User_Guide/b_IFC_RESTful_API_User_Guide_chapter_010.html#concept_1B75A78853DD46AABC15B048AAFAD1AD

| moquery Operator | REST API Operator |
| --- | --- |
| == | eq |
| != | ne |
| >= | ge |
| > | gt |
| <= | le |
| < | lt |
| and | and |
| or | or |
| ~ | bw |
| * | wcard |


 - They’re all binary operators so they’re used between two operands.
 - With the exception of the the ‘and’ and ‘or’ operators, the first operand must be a property name in the form: package.class.property (example, fv.AEPg.name). Package names are documented here: https://developer.cisco.com/media/mim-ref/mim_help.html#Packages. The package name is the string before the colon in the class names as documented here: https://developer.cisco.com/media/mim-ref/
 - Single quotes must be used to enclose the query filter, double quotes must be used to enclose the second operand, even if the second operand is an integer. See example #2 below.
 - The second operand for the ~ operator is of the form (integer1, integer2). The second operand must be enclosed in double quotes, as above. The integers must not be enclosed in quotes. See example #3 below.

# Examples

```console
moquery -c fvAEPg -f ‘fv.AEPg.name*"ad"'
```
Return all application EPGs with ‘ad’ in the name property

```console
moquery -c fvAEPg -f 'fv.AEPg.pcTag<="16384"'
```
Return all application EPGs that have global pcTag

```console
moquery -c fvAEPg -f 'fv.AEPg.pcTag~"(10933,10934)"'
```
Return all application EPGs that have pcTag between 10933 and 10934

```console
moquery -c fvAEPg -f 'fv.AEPg.pcTag<="16384" and fv.AEPg.name*"epo"'
```
Return all application EPGs that have global pcTag and ‘epo’ in the name property
