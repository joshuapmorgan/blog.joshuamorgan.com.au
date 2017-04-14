+++
date = "2017-02-14T20:07:00+10:00"
tags = ["ACI"]
title = "Cisco ACI Deep Dive: Contracts (Part 1, Introduction)"
aliases = [
	"/2017/02/14/cisco-aci-deep-dive-contracts-part-1-introduction/",
	"/post/cisco-aci-deep-dive-contracts-part-1-introduction/"
]
+++

# Overview

This is the first part in what will be a series of blog posts regarding ACI contracts. From an architecture, design, and operations standpoint, contracts are one of ACI’s features that require the most in-depth understanding. This is because contracts are distilled into policy CAM entries within hardware and due to the laws of physics, hardware is limited – the policy CAM entries require logic gates and there is a finite amount of logic gates that can be placed onto a die. Such an in-depth understanding is currently difficult to accomplish without practical experience (mostly real-world deployment but also labbing) as detailed documentation (beyond procedure on how to configure contracts) really doesn’t exist.


This series assumes intermediate knowledge of ACI, including the various constructs and their configuration using the UI: contracts, endpoint groups, bridge domains, etc.; and an understanding of the management information model/tree.

Most, if not all, of this series focuses on contracts from the perspective of the management information tree (MIT) and hardware rather than the UI – it’s assumed that readers already well and truly know how to configure contracts via the UI, for example.

Some of this series should be taken with a grain of salt, some content is the work of reverse engineering for client projects and may not be 100% accurate.

# Series Parts

Introduction
Zoning Rules
Contract Scopes (future post)
Labels (future post)
Quality of Service (future post)
External Network Instance Profiles (future post)
Service Graphs (future post)
Optimisations (TCP EST) (future post)
vzAny (future post)
Global/Tenant Contracts and Route Leaking (future post)
NorthStar/Donner[C] Programming (future post)
Sugarbowl Programming (future post)
Troubleshooting (future post)

# What are contracts?

Contracts define the connectivity permitted (or denied, in the case of taboo contracts) between endpoint groups (EPGs). Specifically, contracts are currently implemented as stateless packet filters within the ASIC of the leaf switches of the ACI fabric. EPGs can provide, consume or both provide and consume contracts. A contract provider is typically the provider of a service, such as a web service. A contract consumer is typically the consumer of a service provided by someone else. Thus, the provider is the server and the consumer is the client.

A contract is a managed object (MO) of class vz:BrCP. These managed objects are children of a tenant. This MO itself has few configurable properties:

- name
    - Name of the contract.
- prio
    - QoS priority of the contract; discussed in a future post.
- targetDscp
    - Target codepoint of the contract; discussed in a future post.
- scope
    - Scope of the contract; discussed in a future post.
- descr
    - Description of the contract.

The figure below depicts the managed object classes we will be discussing in this part, their relationships and the properties we are considering. If the figure looks familiar, we have used the same tool used by Cisco to generate the class diagrams within the Management Information Model Reference – PlantUML.

![Contracts](/images/cisco-aci-deep-dive-contracts-part-1-introduction_0001.png)

---

**Class Naming Convention**

Managed object classes are named package:class. The list of packages defined is available in the Management Information Model Reference: https://developer.cisco.com/media/mim-ref/mim_help.html in the Package Descriptions table. This table does not appear to have been updated since perhaps v1.2 – some packages, such as ‘bfd’, are absent from the table. Looking at the table we see that the ‘vz’ package name in the class discussed so far denotes ‘virtual zones’ – reportedly the initial name for the contract functionality.

---

Contracts may be configured in the common tenant, where they can be consumed/provided by EPGs from that and any other tenant. In the case that an EPG within a tenant other than common consumes/provides a contract configured in the common tenant, then scoping (discussed in another part) comes into effect.

Contained within a contract MO are multiple non-configurable (some defined later in this series, as they’re useful for troubleshooting) MOs and zero or more subject MOs of class vz:Subj.

# Okay, so what are subjects?

Subject MOs define the connectivity to be permitted or denied by relating to filters, and can include consumer and provider subject labels. Labels are discussed in a future part.

Within the subject MO, the connectivity that is to be permitted or denied is specified via zero or more MOs of class vz:RsSubjFiltAtt. Managed objects of this class define a named relationship to a filter MO of class vz:Filter.

---

**Relationship Managed Objects**

The cool thing about relationship managed objects is that they have a source and target pairing. Perhaps somewhat obviously, the source defines where the relationship is from and the target specifies where the relationship is to. In the case above, the source is the subject (vz:Subj) and the source relationship class is vz:RsSubjFiltAtt. Notice the ‘Rs’ in the class name? Yup, that prefix is for relationship source. The target is the filter (vz:Filter) and the target relationship class is vz:RtSubjFiltAtt. The ‘Rs’ in the class name is the prefix for relationship target. Relationship target managed objects are non-configurable, the APIC automatically creates a corresponding relationship target MO once a relationship source MO is configured. The vz:RtSubjFiltAtt MO is a child MO of the filter (vz:Filter) that the vz:RsSubjFiltAtt MO relates to. In this way, we could use the REST API or an interface to it (such as moquery (now deprecated :-() or Visore) to determine what subjects relate to a particular filter more easily.

---

Subjects, too, have few configurable properties:

- name
    - Name of the subject
- descr
    - Description of the subject
- prio
    - QoS priority of the subject; discussed in a future post.
- targetDscp
    - Target codepoint of the contract; discussed in a future post.
- consMatchT
    - Consumer label match type; discussed in a future post.
- provMatchT
    - Provider label match type; discussed in a future post.
- revFltPorts
    - Causes the reverse filter to automatically be permitted (discussed below).

# Reverse Filter Ports

By default, in the UI, ‘Apply Both Directions’ and ‘Reverse Filter Ports’ options are checked. Reverse Filter Ports specifies the revFltPorts property of the vz:Subj MO. Apply Both Directions, as discussed in the next section, is an abstraction of two MOs.

When Reverse Filter Ports (revFltPorts) is configured, the resolution of the contract into zoning rules results in a reverse zoning rule automatically being configured. This allows easier configuration of the contract and emulates the definition of stateful firewall policy – only the source, destination, and service needs to be considered from the perspective of the connection initiator. The reverse zoning rule configured allows packets from the provider to the consumer (the reply packets).

As an example, consider a contract C1 with subject S1 configured with revFltPorts set to true. The subject S1 is related to a single filter, F1. F1 contains a single entry, E1, that matches packets with destination port 80 (HTTP) and TCP as the Layer 4 protocol. The system will configure two zoning rules (expressed as source, destination, L4 protocol, source L4 port, destination L4 port tuple):

- (Consumer EPG, Provider EPG, TCP, 0, 80)
- (Provider EPG, Consumer EPG, TCP, 80, 0)

Reverse Filter Ports and Apply Both Directions are mutually exclusive. Once Apply Both Directions is unchecked within the UI, Reverse Filter Ports is automatically unchecked, too. The reason for this becomes evident after reading the next section.

# Apply Both Directions

Apply Both Directions is purely a UI abstraction of ‘input/output terminal nodes’. Once Apply Both Directions is unchecked within the UI, the user can configure distinct filter chains for consumer to provider direction and provider to consumer direction. The filter chain for consumer to provider direction is configured as a MO of class vz:InTerm whilst the filter chain for provider to consumer direction is configured as a MO of class vz:OutTerm.

The best way to visualise this is that the contract has a terminal connected to the consumer, the InTerm and a terminal connected to the provider, the OutTerm. The terminals apply their filters to traffic upon ingress. That is, for packets that are sent from consumer to provider, the packets ingress the InTerm and thus filters are applied there (per the figure below, represented by the red terminal). However, the packets egress the OutTerm and therefore the filters related to the OutTerm are not applied.

![Contracts](/images/cisco-aci-deep-dive-contracts-part-1-introduction_0002.png)

Likewise, for packets that are sent from the provider to consumer, the packets ingress the OutTerm and filters are applied there (per the figure below, represented by the red terminal). But, filters are not applied by the InTerm as the packets egress that terminal.

![Contracts 2](/images/cisco-aci-deep-dive-contracts-part-1-introduction_0003.png)

It can be seen that Reverse Filter Ports is irrelevant if specifying separate filter chains for consumer to provider and provider to consumer direction. Reverse Filter Ports merely automatically reverses the filters specified within the filter chain for consumer to provider direction and applies them to the provider to consumer direction. As Apply Both Directions allows the specification of the filter chain for provider to consumer direction, Reverse Filter Ports is irrelevant.

# Filters and Filter Entries

Subjects (vz:Subj) or input/output terminals (vz:InTerm and vz:OutTerm, respectively), as we discussed, are related to filters (vz:Filter) via either vz:RsSubjFiltAtt (for vz:Subj MOs) or vz:RsFiltAtt (for vz:InTerm and vz:OutTerm MOs).

The vz:RsSubjFiltAtt and vz:RsFiltAtt MOs have two properties of interest: directives and tnVzFilterName. The directives property is a bitmask that currently has a single constant specified – log. A vz:RsSubjFiltAtt/vz:RsFiltAtt MO configured with a directive to log will cause frames/packets that match the filter to be logged. The tnVzFilterName property defines the name of the filter for the relation. This property is subject to resolution – if a filter with that name exists in the same tenant, then that filter is referenced, otherwise a lookup is done within the common tenant. If there is no filter with that name in either the same tenant or current tenant, then a resolution-failed fault is raised (F1111, fltVzRsFiltAttResolveFail or F1127, fltVzRsSubjFiltAttResolveFail).

The filter is the MO that defines a group of filter entries (vz:Entry).Each filter MO only includes a configurable name and descr property. Each filter entry is a ‘combination of network traffic classification properties’.

The filter entries are where the fun happens. The filter entries define the network traffic classification properties. The following are the properties of filter entries:

- name
    - Name of the filter entry.
- descr
    - Description of the filter entry.
- applyToFrag
    - Boolean indicating whether this filter entry applies to IP fragments.
- arpOpc
    - 8-bit integer defining the ARP opcode to match. Two constants are defined – ‘req’ (0) and ‘reply’ (1).
- dFromPort
    - Destination from (lower bound) Layer 4 port. Several constants are defined and documented in the Management Information Model Reference.
- dToPort
    - Destination to (upper bound) Layer 4 port. Several constants are defined and documented in the Management Information Model Reference.
- etherT
    - Ethertype of the Ethernet frame to match. This is a 16-bit integer with multiple constants defined and documented in the Management Information Model Reference. The UI only allows selection of the defined constants.
- icmpv4T
    - ICMPv4 type.
- icmpv6T
    - ICMPv6 type.
- matchDscp
    - Differentiated Services Code Point (DSCP).
- prot
    - Layer 3 IP protocol.
- sFromPort
    - Source from (lower bound) Layer 4 port. Several constants are defined and documented in the Management Information Model Reference.
- sToPort
    - Source from (upper bound) Layer 4 port. Several constants are defined and documented in the Management Information Model Reference.
- stateful
    - Boolean to emulate stateful behaviour for TCP flows; discussed further below.
- tcpRules
    - Bitmask specifying TCP flags; discussed further below.

# etherT

The Management Information Model Reference defines multiple constants for this property: unspecified (0), trill (0x22F3), arp (0x0806), mpls_ucast (0x8847), mac_security (0x88E5), fcoe (0x8906), and IP (0xABCD). The astute reader will note the constant values are equivalent to the assigned ethertype code. However, the constant for IP, has value 0xABCD. This constant/value is used to match Ethernet frames with both IPv4 and IPv6 payloads. 0xABCD is currently unassigned as an Ethertype value by the IEEE.

# icmpv4T/icmpv6T

The Management Information Model References defines multiple constants for this property. The constant values are equivalent to the ICMPv4/ICMPv6 type codes as defined in RFC792 and RFC4443, respectively.

# matchDscp

The Management Information Model Reference defines multiple constants for this property. The constant values are equivalent to the decimal Differentiated Services code points. That is, constant EF is assigned value 46.

# prot

The Management Information Model Reference defines multiple constants for this property. The constant values are equivalent to the assigned IP numbers. That is, the constant tcp is assigned value 6 and constant udp is assigned value 17.

# stateful/tcpRules

tcpRules property allows matching flags within the TCP segment header – for example, the SYN/ACK, etc. flags. This property is a bitmask allowing the filter to match multiple set flags. The MIT allows configuration of a bitmask property using comma-delimited constant names. For example, to specify matching a TCP segment with either SYN or ACK flag, a filter defined with tcpRules property equal to ‘ack,syn’ will accomplish the requirement. Furthermore, there is also a convenience constant ‘est’ that matches TCP segments with either ACK or RST flag.

The stateful property is a Boolean property. When configured to true, TCP segments sent from the provider to consumer must have the ACK flag set or the segment is discarded. This property is discussed further in the part on Zoning Rules.
