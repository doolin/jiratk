# frozen_string_literal: true

RSpec.shared_context 'with ticket workflow' do
  let(:origin) { 'https://tickets.example.test' }
  let(:error_class) { JiraTk::Tickets::Error }

  before do
    allow(ENV).to receive(:fetch).with('DOOLIN_JIRA_URL', nil).and_return(origin)
    allow(ENV).to receive(:fetch).with('DOOLIN_JIRA_ID', nil).and_return('synthetic-user')
    allow(ENV).to receive(:fetch).with('DOOLIN_JIRA_API', nil).and_return('synthetic-key')
    stub_ticket_states({})
    stub_routes(route_response)
  end

  def ticket_url
    "#{origin}/rest/api/3/issue/GEN-1"
  end

  def destination
    { 'id' => '10001', 'name' => 'Done' }
  end

  def route_response(changes = {})
    { 'transitions' => [{ 'id' => '31', 'name' => 'Finish work', 'to' => destination,
                          'hasScreen' => false, 'fields' => {} }.merge(changes)] }
  end

  def expected_route
    { 'id' => '31', 'name' => 'Finish work', 'to' => destination, 'has_screen' => false,
      'available' => true, 'required_fields' => [] }
  end

  def stub_ticket_states(*states)
    fields = { 'description' => nil, 'updated' => 'before',
               'status' => { 'id' => '10002', 'name' => 'Backlog' } }
    responses = states.map do |changes|
      { status: 200, body: JSON.generate('key' => 'GEN-1', 'fields' => fields.merge(changes)) }
    end
    stub_request(:get, ticket_url)
      .with(query: { fields: JiraTk::Tickets::Client::FIELDS.join(',') },
            basic_auth: %w[synthetic-user synthetic-key]).to_return(*responses)
  end

  def stub_routes(*responses)
    stub_route_request.to_return(*responses.map { |body| { status: 200, body: JSON.generate(body) } })
  end

  def stub_route_request
    stub_request(:get, "#{ticket_url}/transitions")
      .with(query: { expand: 'transitions.fields' }, basic_auth: %w[synthetic-user synthetic-key])
  end

  def stub_transition(status: 204)
    stub_request(:post, "#{ticket_url}/transitions")
      .with(body: JSON.generate(transition: { id: '31' }), basic_auth: %w[synthetic-user synthetic-key],
            headers: { 'Content-Type' => 'application/json' }).to_return(status: status, body: 'private response')
  end
end
