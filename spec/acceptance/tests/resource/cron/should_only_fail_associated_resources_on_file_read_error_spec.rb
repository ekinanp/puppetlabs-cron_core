require 'spec_helper_acceptance'

RSpec.context 'when Puppet cannot read a crontab file' do
  username = "pl#{rand(999999).to_i}"
  unknown_username = "pl#{rand(999999).to_i}"

  before(:each) do
    step "Create the known user" do
      compatible_agents.each do |agent|
        user_present(agent, username)
      end
    end

    step "Ensure that the unknown user does not exist" do
      compatible_agents.each do |agent|
        user_absent(agent, unknown_username)
      end
    end
  end

  after(:each) do
    step "Teardown -- Erase the known user on the agents" do
      compatible_agents.each do |agent|
        run_cron_on(agent, :remove, username)
        user_absent(agent, username)
      end
    end
  end

  compatible_agents.each do |agent|
    it "should only fail the associated resources on #{agent}" do
      puppet_result = nil
      step "Add some cron entries with Puppet" do
        manifest = [
          cron_manifest('first_entry', command: "ls", user: username),
          cron_manifest('second_entry', command: "ls", user: unknown_username),
        ].join("\n\n")
  
        puppet_result = apply_manifest_on(agent, manifest)
      end
  
      step "Verify that Puppet fails a Cron resource associated with an unreadable crontab file" do
        assert_match(/Cron.*second_entry/, puppet_result.stderr, "Puppet does not fail a Cron resource associated with an unreadable crontab file")
      end
  
      step "Verify that Puppet does not fail a Cron resource associated with a readable crontab file" do
        assert_no_match(/Cron.*first_entry/, puppet_result.stderr, "Puppet fails a Cron resource associated with a readable crontab file")
      end
  
      step "Verify that Puppet successfully evaluates a Cron resource associated with a readable crontab file" do
        assert_match(/Cron.*first_entry/, puppet_result.stdout, "Puppet fails to evaluate a Cron resource associated with a readable crontab file")
      end
  
      step "Verify that Puppet did update the readable crontab file with the Cron resource" do
        assert_matching_arrays(["* * * * * ls"], crontab_entries_of(agent, username), "Puppet fails to update a readable crontab file with the specified Cron entry")
      end
    end
  end
end
