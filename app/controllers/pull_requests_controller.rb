require 'remote_server'

# TODO: Combine this controller with RepositoriesController#build_ref
class PullRequestsController < ApplicationController

  def build
    if payload['host']
      @repository = Repository.lookup(host: payload["host"], namespace: payload["repository"]["key"], name:payload["repository"]["slug"])
    else
      url = payload['repository']['url'] || payload['repository']['ssh_url']
      ssh_url = RemoteServer.for_url(url).canonical_repository_url
      @repository = Repository.lookup_by_url(ssh_url)
    end

    handle_pull_request if payload["pull_request"]
    handle_repo_push_request if payload["ref"]
    render :json => {:message => "Thanks!"}
  end

  protected

  def handle_repo_push_request
    return unless @repository

    project = @repository.projects.where(name: @repository.name).first_or_create
    if payload["ref"] == "refs/heads/master" && @repository.run_ci?
      sha = payload["after"]
      project.builds.create_new_build_for(sha)
    end
  end

  def handle_pull_request
     return unless @repository

    project = @repository.projects.where(name: @repository.name + "-pull_requests").first_or_create
    if active_pull_request? && @repository.build_pull_requests
      sha = payload["pull_request"]["head"]["sha"]
      branch = payload["pull_request"]["head"]["ref"].gsub(%r{^refs/heads/}, '')

      project.ensure_branch_build_exists(branch, sha)
    end
  end

  def active_pull_request?
    payload['action'] && payload['action'] != "closed"
  end

  def payload
    @payload ||= JSON.parse params["payload"]
  end
end
