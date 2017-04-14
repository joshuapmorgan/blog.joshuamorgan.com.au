+++
date = "2017-02-18T20:59:00+10:00"
tags = ["ACI"]
title = "Cisco ACI Deep Dive: Contracts (Part 2, Zoning Rules)"
aliases = [
	"/2017/02/18/cisco-aci-deep-dive-contracts-part-2-zoning-rules/",
	"/post/cisco-aci-deep-dive-contracts-part-2-zoning-rules/"
]
+++

# Overview

As mentioned in Part 1, contracts are distilled into policy CAM entries in hardware to implement their function. However, prior to that contracts are first resolved into zoning rules.

Per Cisco’s Troubleshooting Application Centric Infrastructure, within the ACI object model, there are three stages of models: logical, resolved, and concrete. The logical model is composed of managed objects that the user manipulates via the REST API or GUI/CLI (which utilise the REST API ‘under the hood’). Managed objects such as fv:AEPg (application EPG), vz:BrCP (Contract), vz:Filter (Filter) comprise the logical model. Resolved managed objects are those that the APIC automatically instantiates based upon resolving the logical model. Finally, the concrete model are managed objects that define the configuration delivered to each fabric node based on the resolved model and endpoint attachment.

Determining the managed object classes that belong to the resolved or concrete models is not possible, as it is not publicly documented. For the purposes of this post, we will assume that zoning rules and filters are a member of the concrete model as they are present on the leaf switches after contracts have been resolved and are dependent on endpoint attachment (specifically, whether an EPG is deployed to that given leaf switch).

Zoning rules are essentially an entry within a packet filter that applies policy enforcement to transit traffic. Thus, it is a tuple defining frames/packets to match and action(s) to take if the rule is matched. Rules are processed in order (depending on the rule identifier and priority, refer to Zoning Rule Priority section later in this post), until a match is found.

# Series Parts

1. Introduction
2. Zoning Rules
3. Contract Scopes (future post)
4. Labels (future post)
5. Quality of Service (future post)
6. External Network Instance Profiles (future post)
7. Service Graphs (future post)
8. Optimisations (TCP EST) (future post)
9. vzAny (future post)
10. Global/Tenant Contracts and Route Leaking (future post)
11. NorthStar/Donner[C] Programming (future post)
12. Sugarbowl Programming (future post)
13. Troubleshooting (future post)

# Zoning Rules

Zoning rules are managed objects of class actrl:Rule. The actrl prefix, as you may have guessed, denotes package ‘access control’. The actrl:Rule managed object class includes the following properties:

- action
    - Action of the rule. This property is a bitmask that may include the following flags: deny, count, log, copy, permit, and redir.
- dPcTag
    - 16-bit integer identifying the destination EPG; refer to pcTag/sclass section later in this post.
- direction
    - Direction of the rule, either: uni-dir, bi-dir, or uni-dir-ignore. In practice, only uni-dir is seen.
- fltId
    - 32-bit integer identifying the zoning filter (actrl:Flt, not vz:Filter).
- id
    - 32-bit integer to uniquely identify the rule.
- markDscp
    - Differentiated Services Code Point to mark packets that match this rule; discussed in a future post.
- operSt
    - Operational status of the rule, either enabled or disabled.
- operStQual
    - If the operational status of the rule is disabled, this property may contain either: hwprog-fail, swprog-fail, hwprog-fail-tcam-full. swprog-fail is likely only relevant for management rules as those rules involve the configuration of iptables on the fabric nodes.
- prio
    - Priority of the zoning rule, this is essentially used to ensure that most specific zoning rules are matched first. Refer to Zoning Rule Priority section later in this post.
- qosGrp
    - QoS group; discussed in a future post.
- sPcTag
    - 16-bit integer identifying the source EPG; refer to pcTag/sclass section later in this post.
- scopeId
    - 32-bit integer identifying the VRF/context.
- type
    - Type of zoning rule, either: tenant, mgmt, snmp, bd_flood, vrf_default, or infra.

![Zoning Rules Managed Object Classes](/images/cisco-aci-deep-dive-contracts-part-2-zoning-rules_0001.png)

As the zoning rules and filters belong to the concrete model, we can obtain them from the Management Information Tree (MIT) of either the APIC or the leaf switch. It’s important to note where these objects belong depending on whether we’re accessing them from the APIC or the leaf switch:

![Zoning Rules MIT Location](/images/cisco-aci-deep-dive-contracts-part-2-zoning-rules_0002.png)

# pcTag/sclass

Some form of numeric identifier is required to identify EPGs within the hardware. This is the pcTag/sclass identifier. Within the GUI and CLI, this attribute of an EPG is referred interchangeably as either pcTag or sclass.

Note that any managed object class that inherits from fv:ATg (Attachable Target Group) has a pcTag property. This includes fv:AEPg (Application EPG), l2ext:InstP (External Network Instance Profile) and l3ext:InstP (External Network Instance Profile). For the purposes of this article, ‘EPG’ refers to any managed object of those classes.

There are a few ways to determine the pcTag of an EPG. One method is to query the MIT using Visore/moquery/REST API:

```console
apic1# moquery -c fvAEPg -f 'fv.AEPg.name=="app1-app"' | grep pcTag
pcTag : 32771
```

Note that fvAEPg is not available on the fabric nodes, only on the controller. On leaf switches, one can determine the pcTag via ELTMC provided the VLAN ID is known. Here we determine the pcTag for the app1-app EPG within the app1 application profile of tenant1 (note in the output the pcTag is referred to as sclass):

```console
leaf3# show vlan brief

 VLAN Name                             Status    Ports                           
 ---- -------------------------------- --------- ------------------------------- 
 2    infra:default                    active    Eth1/3, Eth1/4, Eth1/5          
 36   tenant1:bd1                      active    Eth1/1, Eth1/2, Po1, Po2 
 37   tenant1:app1:app1-app            active    Eth1/1, Eth1/2, Po1, Po2 
 38   tenant1:app1:app1-db             active    Eth1/1, Eth1/2, Po1, Po2 

leaf3# vsh_lc
vsh_lc
module-1# show system internal eltmc info vlan 37


             vlan_id:             37   :::      hw_vlan_id:             39
           vlan_type:        FD_VLAN   :::         bd_vlan:             36
   access_encap_type:         802.1q   :::    access_encap:           3007
            isolated:              0   :::   primary_encap:              0
   fabric_encap_type:          VXLAN   :::    fabric_encap:          20699
              sclass:          32771   :::           scope:             38
             bd_vnid:          20699   :::        untagged:              0
     acess_encap_hex:          0xbbf   :::  fabric_enc_hex:         0x50db
     pd_vlan_ft_mask:           0x4f
    fd_learn_disable:              0
        bcm_class_id:             16   :::  bcm_qos_pap_id:           1024
          qq_met_ptr:             20   :::       seg_label:              0
      ns_qos_map_idx:              0   :::  ns_qos_map_pri:              1
     ns_qos_map_dscp:              0   :::   ns_qos_map_tc:              0
        vlan_ft_mask:         0x7830

      NorthStar Info:
           qq_tbl_id:            257   :::         qq_ocam:              0
     seg_stat_tbl_id:              0   :::        seg_ocam:              0
::::
```

The vsh_lc shell is used to access runtime state of the line card. For fixed configuration models, this is the entire switch.

pcTags can either be global or local. We will discuss this in a future post but essentially global means the pcTag is globally unique across the fabric, whilst local signifies that the pcTag is locally significant for the scope (VRF/context).

# Zoning Filters

The filters (and their entries) configured by a user in the logical model are then resolved into actrl:Flt and actrl:Entry, as required (see Zoning Rule Deployment).

actrl:Flt managed objects, like the vz:Filter managed object that they are resolved from, together with their child entries (actrl:Entry or vz:Entry) are responsible for defining classification properties to match frames/packets.

actrl:Flt managed objects include one interesting property:

 - id
    - 32-bit integer to uniquely identify the filter.

actrl:Entry managed objects are children of actrl:Flt managed objects. In practice, the APIC configures a single actrl:Entry managed object per actrl:Flt managed object.

actrl:Entry managed objects include the following properties:

- applyToFrag
- arpOpc
- dFromPort
- dToPort
- etherT
- icmpv4T
- icmpv6T
- matchDscp
- prot
- sFromPort
- sToPort
- stateful
- tcpRules

All of these properties serve the same purpose as properties of the same name of the vz:Entry managed object class, discussed in Part 1, so we have not discussed them further here.

# Zoning Rule Priority

Within the actrl:Rule managed object, the prio property can be any of the following (in numerically increasing order):

- class-eq-deny
- class-eq-allow
- prov-nonshared-to-cons
- black_list
- fabric_infra
- fully_qual
- system_incomplete
- src_dst_any
- shsrc_any_filt_perm
- shsrc_any_any_perm
- shsrc_any_any_deny
- src_any_filter
- any_dest_filter
- src_any_any
- any_dest_any
- any_any_filter
- grp_src_any_any_deny
- grp_any_dest_any_deny
- grp_any_any_any_permit
- any_any_any
- any_vrf_any_deny
- default_action

As an example, the fully_qual priority is configured on rules that specify a specific source pcTag, destination pcTag, and filter. Meanwhile, the src_any_filter priority is configured on rules that specify a specific source pcTag, a destination pcTag of ‘any’ (matching all EPGs), and a specfic filter. The fully_qual priority is numerically lower than src_any_filter priority; numerically lower priorities are of higher priority.

Rules are processed ‘top to bottom’ until a match is found. Rules are ordered by highest priority first, then by identifier. This ensures that more specific zoning rules are matched first, rather than generic zoning rules. The priority property is used a lot by shared service functionality – we’ll touch on this in a later post.

# Zoning Rule Deployment

You will recall in the Overview that the concrete model is ‘managed objects that define the configuration delivered to each fabric node based on the resolved model and endpoint attachment’. Within that statement, ‘endpoint attachment’ is of significance – zoning rules are only configured on fabric nodes (leaf switches) as required by the endpoints attached to that leaf switch. For example, zoning rules with a source and destination application EPG are only configured on a leaf switch if the source EPG is deployed to the leaf switch. An EPG is deployed to a leaf switch depending on deployment immediacy of static paths (previously static bindings) or VMM domain association. If either are set to immediate, the EPG is deployed immediately upon configuration. If set to on-demand, the EPG is deployed on-demand once an endpoint is determined to be attached to the leaf switch.

# Example

We’ll now put some of this theory into practice with the configuration of a very basic contract. Throughout the rest of this series, we will be analysing the zoning rules that different contract configurations produce to enhance our understanding of them.

The following diagram depicts the contract configuration used for this example:

![Example Configuration](/images/cisco-aci-deep-dive-contracts-part-2-zoning-rules_0003.png)

We have a single tenant, VRF, and application profile with two EPGs: app1-app and app1-db. app1-db provides the ‘db’ contract, whilst app1-app consumes it.

The db contract contains a single subject, db:

```console
apic1# moquery -d uni/tn-tenant1/brc-db/subj-db
Total Objects shown: 1

# vz.Subj
name : db
childAction : 
configIssues : 
consMatchT : AtleastOne
descr : 
dn : uni/tn-tenant1/brc-db/subj-db
lcOwn : local
modTs : 2017-02-16T05:55:54.786+00:00
monPolDn : uni/tn-common/monepg-default
nameAlias : 
prio : unspecified
provMatchT : AtleastOne
revFltPorts : yes
rn : subj-db
status : 
targetDscp : unspecified
uid : 15374
```

Subject db references a single filter, tcp-1521:

```console
apic1# moquery -d uni/tn-tenant1/brc-db/subj-db -c vzRsSubjFiltAtt
Total Objects shown: 1

# vz.RsSubjFiltAtt
tnVzFilterName : tcp-1521
childAction : 
directives : 
dn : uni/tn-tenant1/brc-db/subj-db/rssubjFiltAtt-tcp-1521
forceResolve : yes
lcOwn : local
modTs : 2017-02-16T05:58:48.384+00:00
monPolDn : uni/tn-common/monepg-default
rType : mo
rn : rssubjFiltAtt-tcp-1521
state : formed
stateQual : none
status : 
tCl : vzFilter
tContextDn : 
tDn : uni/tn-common/flt-tcp-1521
tRn : flt-tcp-1521
tType : name
uid : 15374

apic1# moquery -c vzFilter -f 'vz.Filter.name=="tcp-1521"'
Total Objects shown: 1

# vz.Filter
name : tcp-1521
childAction : 
descr : None
dn : uni/tn-common/flt-tcp-1521
fwdId : 791
id : implicit
lcOwn : local
modTs : 2016-05-11T01:25:52.108+00:00
monPolDn : uni/tn-common/monepg-default
nameAlias : 
ownerKey : 
ownerTag : 
revId : 792
rn : flt-tcp-1521
status : 
txId : 0
uid : 15374
usesIds : yes
```

Note that the tnVzFilterName property of the vzRsSubjFiltAtt managed object references a name and not a distinguished name. This property is subject to the resolution discussed in Part 1. As no filter named tcp-1521 exists in tenant1, this resolves to the filter named tcp-1521 that exists in the common tenant – the tDn property is automatically populated by the APIC based on this resolution result. Note this resolution is distinct to the resolution from concrete model to resolved model discussed earlier in this post.

Filter tcp-1521 includes a single entry:

```console
apic1# moquery -d uni/tn-common/flt-tcp-1521 -c vzEntry
Total Objects shown: 1

# vz.Entry
name : tcp-1521
applyToFrag : no
arpOpc : unspecified
childAction : 
dFromPort : 1521
dToPort : 1521
descr : 
dn : uni/tn-common/flt-tcp-1521/e-tcp-1521
etherT : ip
icmpv4T : unspecified
icmpv6T : unspecified
lcOwn : local
matchDscp : unspecified
modTs : 2016-05-11T01:25:52.108+00:00
monPolDn : 
nameAlias : 
prot : tcp
rn : e-tcp-1521
sFromPort : unspecified
sToPort : unspecified
stateful : no
status : 
tcpRules : 
uid : 15374
```

With reference to Part 1, the above managed objects should be easily understood as to their intent. Note that Reverse Filter Ports (revFltPorts) has been configured for the subject used in this example.

The leaf switch includes a show zoning-rule command that may be used to view the zoning rules configured on that switch. This command merely outputs the actrl:Rule managed objects and can be filtered based on source or destination pcTag, or scope. There may be many rules configured on a leaf switch, so it’s best to filter them. Let’s filter by scope ID.

First we need to determine the scope ID of the vrf1 VRF within tenant1. In our lab configuration, there is only one vrf1 configured so we can get away by not being specific about the tenant:

```console
apic1# moquery -c fvCtx -f 'fv.Ctx.name=="vrf1"' | grep scope
scope : 2326535
```

We also need to get the pcTags for the EPGs in question, the consumer app1-app and provider app1-db:

```console
apic1# moquery -c fvAEPg -f 'fv.AEPg.name=="app1-app"' | grep pcTag
pcTag : 32771
apic1# moquery -c fvAEPg -f 'fv.AEPg.name=="app1-db"' | grep pcTag
pcTag : 49156
```

With the scope ID in hand, we can view the zoning rules configured for that scope:

```console
leaf3# show zoning-rule scope 2326535
Rule ID         SrcEPG          DstEPG          FilterID        operSt          Scope           Action                              Priority       
=======         ======          ======          ========        ======          =====           ======                              ========       
4654            0               49153           implicit        enabled         2326535         permit                              any_dest_any(15)
4655            0               0               implicit        enabled         2326535         deny,log                            any_any_any(20)
4656            0               0               implarp         enabled         2326535         permit                              any_any_filter(16)
4657            0               15              implicit        enabled         2326535         deny,log                            any_vrf_any_deny(21)
4681            49156           32771           792             enabled         2326535         permit                              fully_qual(6)  
4682            32771           49156           791             enabled         2326535         permit                              fully_qual(6)  
```

We can see that within scope 2326535 there are two zoning rules that reference our EPGs, rules 4681 and 4682. The former references filter 792, the latter filter 791.

In order to determine what each filter is specifying, we can use the show zoning-filter command:

```console
leaf3# show zoning-filter filter 791
FilterId  Name          EtherT      ArpOpc      Prot        MatchOnlyFrag Stateful SFromPort   SToPort     DFromPort   DToPort     Prio        Icmpv4T     Icmpv6T     TcpRules   
========  ===========   ======      =========   =======     ======        =======  =======     ====        ====        ====        =========   =======     ========    ========   
791       791_0         ip          unspecified tcp         no            no       unspecified unspecified 1521        1521        dport       unspecified unspecified            

leaf3# show zoning-filter filter 792 
FilterId  Name          EtherT      ArpOpc      Prot        MatchOnlyFrag Stateful SFromPort   SToPort     DFromPort   DToPort     Prio        Icmpv4T     Icmpv6T     TcpRules   
========  ===========   ======      =========   =======     ======        =======  =======     ====        ====        ====        =========   =======     ========    ========   
792       792_0         ip          unspecified tcp         no            no       1521        1521        unspecified unspecified sport       unspecified unspecified
```

The show zoning-filter command prints the actrl:Entry managed objects for a given actrl:Flt id.

Recall that our subject is configured to reverse filter ports. The vz:Filter tcp-1521 child entry is configured with destination port 1521, thus filter 792 is a result of the reverse filter ports configuration of the vz:Subj managed object. As contracts/zoning rules are merely a stateless packet filter, rule 4682 allows packets destined to app1-db from app1-app with destination TCP port 1521 whilst rule 4681 allows the reply traffic – packets from app1-db destined to app1-app with source TCP port 1521.

We can also query the MIT to view additional attributes of the actrl:Rule, actrl:Flt, and actrl:Entry managed objects:

```console
leaf3# moquery -c actrlRule -f 'actrl.Rule.id=="4681"'
Total Objects shown: 1

# actrl.Rule
scopeId : 2326535
sPcTag : 49156
dPcTag : 32771
fltId : 792
action : permit
actrlCfgFailedBmp : 
actrlCfgFailedTs : 00:00:00:00.000
actrlCfgState : 0
childAction : 
descr : 
direction : uni-dir
dn : sys/actrl/scope-2326535/rule-2326535-s-49156-d-32771-f-792
id : 4681
lcOwn : local
markDscp : unspecified
modTs : 2017-02-18T04:43:23.119+00:00
monPolDn : uni/tn-common/monepg-default
name : 
nameAlias : 
operSt : enabled
operStQual : 
prio : fully_qual
qosGrp : unspecified
rn : rule-2326535-s-49156-d-32771-f-792
status : 
type : tenant

leaf3# moquery -c actrlFlt -f 'actrl.Flt.id=="791"'
Total Objects shown: 1

# actrl.Flt
id : 791
childAction : 
descr : 
dn : sys/actrl/filt-791
lcOwn : policy
modTs : 2017-02-18T04:43:04.014+00:00
monPolDn : uni/fabric/monfab-default
name : 
nameAlias : 
ownerKey : 
ownerTag : 
rn : filt-791
status :

leaf3# moquery -d sys/actrl/filt-791 -c actrlEntry
Total Objects shown: 1

# actrl.Entry
name : 791_0
applyToFrag : no
arpOpc : unspecified
childAction : 
dFromPort : 1521
dToPort : 1521
descr : 
dn : sys/actrl/filt-791/ent-791_0
etherT : ip
icmpv4T : unspecified
icmpv6T : unspecified
lcOwn : policy
matchDscp : unspecified
modTs : 2017-02-18T04:43:04.014+00:00
nameAlias : 
prio : dport
prot : tcp
rn : ent-791_0
sFromPort : unspecified
sToPort : unspecified
stateful : no
status : 
tcpRules :
```

In later parts, we will observe how different configurations result in different zoning rules configured/resolved by the APIC and also how the leaf switches program this into hardware.
