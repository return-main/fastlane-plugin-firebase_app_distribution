describe Fastlane::Auth::FirebaseAppDistributionAuthClient do
  let(:auth_client) { Class.new { extend(Fastlane::Auth::FirebaseAppDistributionAuthClient) } }
  let(:fake_binary) { double("Binary") }
  let(:fake_binary_contents) { double("Contents") }
  let(:firebase_auth) { Signet::OAuth2::Client }
  let(:service_auth) { Google::Auth::ServiceAccountCredentials }
  let(:fake_firebase_tools_contents) { "{\"tokens\": {\"refresh_token\": \"refresh_token\"} }" }
  let(:fake_firebase_tools_contents_no_tokens_field) { "{}" }
  let(:fake_firebase_tools_contents_no_refresh_field) { "{\"tokens\": \"empty\"}" }
  let(:fake_service_creds) { double("service_account_creds") }
  let(:fake_oauth_client) { double("oauth_client") }
  let(:payload) { { "access_token" => "service_fake_auth_token" } }

  before(:each) do
    allow(firebase_auth).to receive(:new)
      .and_return(fake_oauth_client)
    allow(fake_oauth_client).to receive(:fetch_access_token!)
    allow(fake_oauth_client).to receive(:access_token)
      .and_return("fake_auth_token")

    allow(service_auth).to receive(:make_creds)
      .and_return(fake_service_creds)
    allow(fake_service_creds).to receive(:fetch_access_token!)
      .and_return(payload)

    allow(File).to receive(:open)
      .and_return(fake_binary)
    allow(fake_binary).to receive(:read)
      .and_return(fake_binary_contents)
    allow(fake_binary_contents).to receive(:key)
      .and_return("fake_service_key")
  end

  describe '#fetch_auth_token' do
    describe 'with all other auth variables as nil or empty' do
      [nil, ""].each do |testval|
        before(:each) do
          allow(ENV).to receive(:[])
            .with("GOOGLE_APPLICATION_CREDENTIALS")
            .and_return(testval)
          allow(ENV).to receive(:[])
            .with("FIREBASE_TOKEN")
            .and_return(testval)
          allow(ENV).to receive(:[])
            .with("XDG_CONFIG_HOME")
            .and_return(testval)
        end

        it 'auths with service credentials path parameter' do
          expect(auth_client.fetch_auth_token("google_service_path", testval))
            .to eq("service_fake_auth_token")
        end

        it 'auths with service credentials environment variable' do
          allow(ENV).to receive(:[])
            .with("GOOGLE_APPLICATION_CREDENTIALS")
            .and_return("google_service_path")
          expect(auth_client.fetch_auth_token(testval, testval))
            .to eq("service_fake_auth_token")
        end

        it 'auths with firebase token parameter' do
          expect(auth_client.fetch_auth_token(testval, "refresh_token"))
            .to eq("fake_auth_token")
        end

        it 'auths with firebase token environmental variable' do
          allow(ENV).to receive(:[])
            .with("FIREBASE_TOKEN")
            .and_return("refresh_token")
          expect(auth_client.fetch_auth_token(testval, testval))
            .to eq("fake_auth_token")
        end

        it 'auths with firebase tools json' do
          allow(File).to receive(:read)
            .and_return(fake_firebase_tools_contents)
          expect(File).to receive(:exist?).and_return(true)
          expect(auth_client.fetch_auth_token(testval, testval)).to eq("fake_auth_token")
        end

        it 'crashes if no credentials are given and firebase tools json does not exist' do
          expect(File).to receive(:exist?)
            .and_return(false)
          expect { auth_client.fetch_auth_token(testval, testval) }
            .to raise_error(ErrorMessage::MISSING_CREDENTIALS)
        end

        it 'crashes if the service credentials file is not found' do
          expect(File).to receive(:open)
            .with("invalid_service_path")
            .and_raise(Errno::ENOENT.new("file not found"))
          expect { auth_client.fetch_auth_token("invalid_service_path", testval) }
            .to raise_error("#{ErrorMessage::SERVICE_CREDENTIALS_NOT_FOUND}: invalid_service_path")
        end

        it 'crashes if the service credentials are invalid' do
          expect(fake_service_creds).to receive(:fetch_access_token!)
            .and_raise(Signet::AuthorizationError.new("error"))
          expect { auth_client.fetch_auth_token("invalid_service_path", testval) }
            .to raise_error("#{ErrorMessage::SERVICE_CREDENTIALS_ERROR}: invalid_service_path")
        end

        it 'crashes if given an invalid firebase token' do
          expect(firebase_auth).to receive(:new)
            .and_raise(Signet::AuthorizationError.new("error"))
          expect { auth_client.fetch_auth_token(testval, "invalid_refresh_token") }
            .to raise_error(ErrorMessage::REFRESH_TOKEN_ERROR)
        end

        it 'crashes if the firebase tools has no tokens field' do
          allow(File).to receive(:read)
            .and_return(fake_firebase_tools_contents_no_tokens_field)
          expect(File).to receive(:exist?).and_return(true)
          expect { auth_client.fetch_auth_token(testval, testval) }
            .to raise_error(ErrorMessage::MISSING_CREDENTIALS)
        end

        it 'crashes if the firebase tools has no refresh_token field' do
          allow(File).to receive(:read)
            .and_return(fake_firebase_tools_contents_no_refresh_field)
          expect(File).to receive(:exist?).and_return(true)
          expect { auth_client.fetch_auth_token(testval, testval) }
            .to raise_error(ErrorMessage::MISSING_CREDENTIALS)
        end
      end
    end
  end
end
