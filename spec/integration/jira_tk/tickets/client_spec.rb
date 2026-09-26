# frozen_string_literal: true

require_relative '../../../support/ticket_workflow'

RSpec.describe JiraTk::Tickets::Client do
  subject(:client) { described_class.new }

  include_context 'with ticket workflow'

  describe '#transitions' do
    it 'lists the verified status and allowlisted routes', :aggregate_failures do
      stub_routes(route_response('private' => 'omit', 'to' => destination.merge('private' => 'omit')))
      result = client.transitions('GEN-1')
      expect(result).to eq('key' => 'GEN-1', 'current' => { 'id' => '10002', 'name' => 'Backlog' },
                           'transitions' => [expected_route])
      expect(WebMock).not_to have_requested(:post, "#{ticket_url}/transitions")
    end

    it 'allows an empty list without inventing routes' do
      stub_routes('transitions' => [])
      expect(client.transitions('GEN-1')['transitions']).to eq([])
    end

    [nil, {}, { 'transitions' => nil }, { 'transitions' => {} }].each do |body|
      it 'rejects malformed route listings' do
        stub_routes(body)
        expect { client.transitions('GEN-1') }.to raise_error(error_class, /invalid/)
      end
    end

    it 'rejects duplicate IDs even if their destination names differ' do
      body = route_response
      body['transitions'] << body['transitions'].first.merge('to' => { 'id' => '3', 'name' => 'Review' })
      stub_routes(body)
      expect { client.transitions('GEN-1') }.to raise_error(error_class, /duplicate transition IDs/)
    end

    it 'rejects invalid issue keys before any request', :aggregate_failures do
      expect { client.transitions('../GEN-1') }.to raise_error(error_class, /Invalid Jira issue key/)
      expect(WebMock).not_to have_requested(:get, ticket_url)
    end

    it 'sanitizes malformed JSON and its exception cause', :aggregate_failures do
      stub_route_request.to_return(status: 200, body: 'private invalid JSON')
      expect { client.transitions('GEN-1') }.to raise_error(error_class, /invalid JSON/) do |error|
        expect(error.cause).to be_nil
      end
    end

    it 'rejects redirects without forwarding credentials', :aggregate_failures do
      stub_route_request.to_return(status: 302, headers: { location: 'https://untrusted.test/' })
      expect { client.transitions('GEN-1') }.to raise_error(error_class, /HTTP 302/)
      expect(WebMock).not_to have_requested(:get, 'https://untrusted.test/')
    end
  end

  describe '#transition' do
    [false, nil, 'true', 1].each do |apply|
      it 'requires Boolean true before writing', :aggregate_failures do
        result = client.transition('GEN-1', to: 'Done', apply: apply)
        expect(result).to eq('key' => 'GEN-1', 'status' => 'dry-run',
                             'from' => { 'id' => '10002', 'name' => 'Backlog' }, 'transition' => expected_route)
        expect(WebMock).not_to have_requested(:post, "#{ticket_url}/transitions")
      end
    end

    it 'defaults to a preview', :aggregate_failures do
      expect(client.transition('GEN-1', to: 'Done')['status']).to eq('dry-run')
      expect(WebMock).not_to have_requested(:post, "#{ticket_url}/transitions")
    end

    [false, true].each do |apply|
      it 'makes an already-complete ticket a verified no-op', :aggregate_failures do
        stub_ticket_states('status' => destination)
        expect(client.transition('GEN-1', to: 'Done', apply: apply))
          .to eq('key' => 'GEN-1', 'status' => 'unchanged', 'current' => destination)
        expect(WebMock).not_to have_requested(:post, "#{ticket_url}/transitions")
        expect(WebMock).not_to have_requested(:get, "#{ticket_url}/transitions")
      end
    end

    [nil, '', ' ', 5].each do |target|
      it 'rejects invalid destination arguments before reading' do
        expect { client.transition('GEN-1', to: target, apply: true) }
          .to raise_error(error_class, /nonempty destination/)
      end
    end

    ['done', 'Finish work', 'Missing'].each do |target|
      it 'selects exact destination names rather than transition names', :aggregate_failures do
        expect { client.transition('GEN-1', to: target, apply: true) }
          .to raise_error(error_class, /unavailable or ambiguous/)
        expect(WebMock).not_to have_requested(:post, "#{ticket_url}/transitions")
      end
    end

    it 'rejects two routes to the requested destination', :aggregate_failures do
      body = route_response
      body['transitions'] << body['transitions'].first.merge('id' => '32')
      stub_routes(body)
      expect { client.transition('GEN-1', to: 'Done', apply: true) }.to raise_error(error_class, /ambiguous/)
      expect(WebMock).not_to have_requested(:post, "#{ticket_url}/transitions")
    end

    it 'writes only the selected ID and reads the resulting status', :aggregate_failures do
      stub_ticket_states({}, {}, { 'status' => destination, 'updated' => 'after' })
      write = stub_transition
      result = client.transition('GEN-1', to: 'Done', apply: true)
      expect(result).to include('status' => 'applied', 'current' => destination)
      expect(write).to have_been_requested.once
    end

    it 'verifies a repeat as a no-op', :aggregate_failures do
      stub_ticket_states({}, {}, { 'status' => destination })
      write = stub_transition
      client.transition('GEN-1', to: 'Done', apply: true)
      expect(client.transition('GEN-1', to: 'Done', apply: true)['status']).to eq('unchanged')
      expect(write).to have_been_requested.once
    end

    [{ 'updated' => 'concurrent edit' }, { 'status' => { 'id' => '3', 'name' => 'Review' } }].each do |changes|
      it 'stops on ticket drift before writing', :aggregate_failures do
        stub_ticket_states({}, changes)
        expect { client.transition('GEN-1', to: 'Done', apply: true) }.to raise_error(error_class, /changed during/)
        expect(WebMock).not_to have_requested(:post, "#{ticket_url}/transitions")
      end
    end

    [{ 'id' => '32' }, { 'to' => { 'id' => '9', 'name' => 'Done' } }, { 'hasScreen' => true }].each do |changes|
      it 'stops on route drift before writing', :aggregate_failures do
        stub_routes(route_response, route_response(changes))
        expect { client.transition('GEN-1', to: 'Done', apply: true) }.to raise_error(error_class, /changed during/)
        expect(WebMock).not_to have_requested(:post, "#{ticket_url}/transitions")
      end
    end

    it 'stops if the selected route disappears during preparation', :aggregate_failures do
      stub_routes(route_response, { 'transitions' => [] })
      expect { client.transition('GEN-1', to: 'Done', apply: true) }.to raise_error(error_class, /unavailable/)
      expect(WebMock).not_to have_requested(:post, "#{ticket_url}/transitions")
    end

    it 'stops if required fields appear during preparation', :aggregate_failures do
      stub_routes(route_response, route_response('fields' => { 'resolution' => { 'required' => true } }))
      expect { client.transition('GEN-1', to: 'Done', apply: true) }.to raise_error(error_class, /requires fields/)
      expect(WebMock).not_to have_requested(:post, "#{ticket_url}/transitions")
    end

    [200, 201, 302, 400, 401, 403, 404, 409, 422, 429].each do |status|
      it "rejects HTTP #{status} without repeating the POST", :aggregate_failures do
        write = stub_transition(status: status)
        expect { client.transition('GEN-1', to: 'Done', apply: true) }
          .to raise_error(error_class, "Ticket transition failed (HTTP #{status}); inspect before retrying")
        expect(write).to have_been_requested.once
      end
    end

    [500, 502, 503].each do |status|
      it 'sanitizes server errors without retrying', :aggregate_failures do
        write = stub_transition(status: status)
        expect { client.transition('GEN-1', to: 'Done', apply: true) }
          .to raise_error(error_class, /outcome may be unknown/) { |error| expect(error.cause).to be_nil }
        expect(write).to have_been_requested.once
      end
    end

    it 'does not follow POST redirects', :aggregate_failures do
      stub_request(:post, "#{ticket_url}/transitions").to_return(status: 307,
                                                                 headers: { location: 'https://untrusted.test/' })
      expect { client.transition('GEN-1', to: 'Done', apply: true) }.to raise_error(error_class, /HTTP 307/)
      expect(WebMock).not_to have_requested(:post, 'https://untrusted.test/')
    end

    it 'reports a timeout without replaying the write', :aggregate_failures do
      write = stub_request(:post, "#{ticket_url}/transitions").to_timeout
      expect do
        client.transition('GEN-1', to: 'Done', apply: true)
      end.to raise_error(error_class, /outcome may be unknown/)
      expect(write).to have_been_requested.once
    end

    it 'reports an unsuccessful readback as uncertain', :aggregate_failures do
      write = stub_transition
      expect do
        client.transition('GEN-1', to: 'Done', apply: true)
      end.to raise_error(error_class, /could not be verified/)
      expect(write).to have_been_requested.once
    end

    it 'reports a failed readback request without repeating the write', :aggregate_failures do
      stub_ticket_states({}, {}).then.to_return(status: 403, body: 'private response')
      write = stub_transition
      expect { client.transition('GEN-1', to: 'Done', apply: true) }
        .to raise_error(error_class, /could not be verified/) { |error| expect(error.cause).to be_nil }
      expect(write).to have_been_requested.once
    end

    [nil, { 'id' => '9', 'name' => 'Done' }, { 'id' => '10001', 'name' => 'Renamed' }].each do |status|
      it 'requires exact destination identity during readback', :aggregate_failures do
        stub_ticket_states({}, {}, { 'status' => status })
        write = stub_transition
        expect { client.transition('GEN-1', to: 'Done', apply: true) }
          .to raise_error(error_class, /could not be verified/)
        expect(write).to have_been_requested.once
      end
    end
  end
end
