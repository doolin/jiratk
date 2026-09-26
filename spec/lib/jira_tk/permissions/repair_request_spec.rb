# frozen_string_literal: true

require_relative '../../../support/permission_plan'

RSpec.describe JiraTk::Permissions::RepairRequest do
  subject(:request) { described_class.new(**repair_options) }

  include_context 'with a permission repair plan'

  [{ account_id: nil }, { service_group_id: '' }, { broad_holder_id: false },
   { projects: [] }, { projects: %w[PAH GEN GEN] }, { projects: %w[PAH] },
   { projects: ['../PAH', 'GEN'] }, { service_group_id: 'fc8e7ac7-be76-4f1b-b481-6221f06b20a8' }].each do |changes|
    it 'rejects invalid expectations before discovery', :aggregate_failures do
      expect { described_class.new(**repair_options, **changes) }.to raise_error(error_class)
      expect(a_request(:get, "#{origin}/rest/api/3/myself")).not_to have_been_made
    end
  end

  it 'requires the caller to declare the broad holder identity explicitly' do
    expect { described_class.new(account_id: 'service-account', service_group_id: 'service-group') }
      .to raise_error(ArgumentError, /broad_holder_id/)
  end

  it 'retains an explicitly empty application-role identity' do
    expect(described_class.new(**repair_options, broad_holder_id: '').to_h['broad_grant']['holder']['id']).to eq('')
  end

  it 'does not allow a returned expectation to alter the request' do
    request.to_h['scheme']['projects'].clear

    expect(request.to_h['scheme']['projects']).to eq(%w[GEN PAH])
  end
end
