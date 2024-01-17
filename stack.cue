package main

import (
	"stakpak.dev/devx/v1"
	"stakpak.dev/devx/v1/traits"
	v2traits "stakpak.dev/devx/v2alpha1/traits"
	wftasks "stakpak.dev/devx/v2alpha1/workflow/tasks"
	wftriggers "stakpak.dev/devx/v2alpha1/workflow/triggers"
)

stack: v1.#Stack & {
	components: {
		demoapp: {
			traits.#Workload
			containers: default: {
				image: "hashicorp/demo-webapp:v3"
				resources: requests: {
					cpu:    "256m"
					memory: "512M"
				}
			}
			traits.#Exposable
			endpoints: default: ports: [{
				port: 80
			}]
		}
		demoapproute: {
			// The HTTPRoute trait exposes some endpoints through your cluster ingress
			traits.#HTTPRoute
			http: {
				listener: "https"
				hostnames: ["demo.guku.io"]
				rules: [{
					match: path: "/*"
					backends: [
						{
							name:       demoapp.appName
							endpoint:   demoapp.endpoints.default
							containers: demoapp.containers
							port:       80
						},
					]
				}]
			}
		}

		githubSecrets: {
			$metadata: labels: secret: "existing"
			// reference to github actions secrets
			traits.#Secret
			secrets: {
				account: name:         "AWS_ACCOUNT"
				accessKeyId: name:     "AWS_ACCESS_KEY_ID"
				accessKeySecret: name: "AWS_SECRET_ACCESS_KEY"
			}
		}
		build: {
			// create the pipeline
			v2traits.#Workflow
			workflow: {
				triggers: {
					push: wftriggers.#PushEvent & {
						filters: tags: ["*"]
					}
				}
				tasks: build: wftasks.#BuildPushECR & {
					repository: "demoapp"
					file:       "./Dockerfile"
					tags: ["${{ github.ref_name }}", "${{ github.sha }}"]
					aws: {
						region:          "eu-north-1"
						account:         githubSecrets.secrets.account
						accessKeyId:     githubSecrets.secrets.accessKeyId
						accessKeySecret: githubSecrets.secrets.accessKeySecret
					}
				}
			}
		}
	}
}
