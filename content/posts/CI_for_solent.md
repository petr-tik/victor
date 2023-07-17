---
title: "CI for Solent-eng"
date: "2017-02-27"
draft: false
tags: 
 - python
 - solent
 - ci
categories: hacking
Author: Petr Tikilyaynen
description:  "Thoughts on setting up own CI"
---

Spent the day working on a plan to build custom CI pipeline for [solent](https://github.com/solent-eng/solent). The design encourages and relies on GitHub-workflow using Pull Requests for all changes - even small ones made by the creator/admin. Will run test suites on different VMs and only allow PR to be merged, if all tests pass. Adding a new VM (for BSD, OSX, minix or other platform) should be: 1) easy, 2) independent of others and independent of the code on master.


## Pull Request workflow

As an OSS project developed in 2017, Solent-eng should have a contributor-friendly way of reviewing issues, pushing changes and testing code. Using the GitHub webhook API, an event loop will notify the master slave of all changes to any Pull Requests (new or existing). This combined with the repo settings preventing from direct pushes to master will make everyone's commits go through the CI suite. This will also apply for the admin, as he is equally human and can make mistakes. Such culture of testing early, often and meritocratically, will help maintain the quality of code with hopefully few regressions. 


## CI master server

Lives on a VM in the cloud. In charge of listening to GitHub hooks, keeps a queue of jobs. Starts and monitors OS-specific VMs that run the test suite as of a given commit. Communicates the outcome of all test runners to the GitHub commit's status API.

## GitHub webhook

A server will listen to events from the GitHub webhook, which in their payload will carry the refs and commit hashes of the PR. Initially, we will consider 3 scenarios:

  * New pull request
  * Changes to a currently open PR
  * Closed and merged a Pull Request
  
### New PR or changes to current PR

First prototype - tear down current VMs of out-of-date commit hash. Start a new set of VMs with the new commit.

Long-term plan: add the new commit hash to the job queue. Run all suites for all commits. 

### Closed and merged a Pull Request

Each test VM, if test suite exits with 0 errors, should build its executable. The CI master will tell each VM to upload the artefact to a location. TODO: hardwire the address inside the VM test runner or pass it as part of the request from the master.


## Test suite VMs

Plans to support linux, BSD, OSX and Windows. All test suites will be run in VMs either in the cloud or on-premises. If tests fail, logs of terminal output should be forwarded to master. TODO: decide how CI-master will show it to GitHub users.
