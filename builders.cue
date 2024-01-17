package main

import (
	"stakpak.dev/devx/v2alpha1"
	"stakpak.dev/devx/v2alpha1/environments"
	"stakpak.dev/devx/v2alpha1/transformers/github"
	eso "stakpak.dev/devx/k8s/services/eso/transformers/kubernetes"
	// keda "stakpak.dev/devx/k8s/services/keda/transformers/kubernetes"
)

builders: v2alpha1.#Environments & {
	default: StandardEnvironment & {
		config: name: "default"
	}
}

StandardEnvironment: environments.#Kubernetes & {
	config: name: string
	drivers: kubernetes: output: dir: ["build", config.name]
	drivers: github: output: dir: [".github", "workflows"]
	config: {
		gateway: {
			name:   "default"
			public: true
			listeners: {
				"http": {
					port:     80
					protocol: "HTTP"
				}
				"https": {
					port:     443
					protocol: "HTTPS"
				}
			}
		}
		routes: ingress: {
			enabled:      true
			defaultClass: "nginx"
		}
	}
	flows: {
		"k8s/external-secret": {
			exclude: labels: secret: "existing"
			pipeline: [
				eso.#AddExternalSecret & {
					k8s: namespace: "default"
					externalSecret: storeRef: name: "main"
				},
			]
		}
		"github/add-workflow": pipeline: [
			github.#AddWorkflow & {
				$metadata: _
				$resources: "\($metadata.id)": {
					permissions: {
						contents:        "read"
						"pull-requests": "write"
					}
				}
			},
		]
	}

	taskfile: tasks: {
		argo: {
			desc: "Port forward to ArgoCD"
			deps: ["check-kubeconfig"]
			cmds: ["kubectl port-forward svc/argo-cd-server -n argo-cd 8080:443"]
		}
		"argo-info": {
			desc: "Get ArgoCD info, username and password"
			deps: ["check-kubeconfig"]
			cmds: [
				"echo \"Open ArgoCD web at https://localhost:8080\"",
				"echo \"username: admin\"",
				"password=$(kubectl -n argo-cd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d) && echo \"password: $password\"",
			]
		}
	}
}
