# frozen_string_literal: true

MY_PATH = 'spec/fixtures/unit/provider/package/pear/'
require 'spec_helper'

describe Puppet::Type.type(:package).provider(:pear) do
  let(:resource) do
    Puppet::Type.type(:package).new name: 'dummy', ensure: :installed
  end

  let(:provider) do
    provider = described_class.new(resource)
    provider.resource = resource
    provider
  end

  before do
    allow(described_class).to receive(:command).with(:pear).and_return '/fake/pear'
    resource.provider = provider
  end

  describe '.instances' do
    it 'returns an array of installed packages' do
      allow(described_class).to receive(:pear).
        with('list', '-a').
        and_return File.read(File.join(MY_PATH, 'list_a'))

      expect(described_class.instances.map(&:properties)).to eq [
        { name: 'Archive_Tar',      vendor: 'pear.php.net', ensure: '1.4.0',  provider: :pear },
        { name: 'Console_Getopt',   vendor: 'pear.php.net', ensure: '1.4.1',  provider: :pear },
        { name: 'PEAR',             vendor: 'pear.php.net', ensure: '1.10.1', provider: :pear },
        { name: 'Structures_Graph', vendor: 'pear.php.net', ensure: '1.1.1',  provider: :pear },
        { name: 'XML_Util',         vendor: 'pear.php.net', ensure: '1.3.0',  provider: :pear },
        { name: 'zip',              vendor: 'pecl.php.net', ensure: '1.13.5', provider: :pear }
      ]
    end

    it 'ignores malformed lines' do
      allow(described_class).to receive(:pear).
        with('list', '-a').
        and_return 'aaa2.1'
      allow(Puppet).to receive(:warning).with('Could not match aaa2.1')
      expect(described_class.instances).to eq []
    end
  end

  describe '#install' do
    it 'installs a package' do
      allow(described_class).to receive(:pear).
        with('-D', 'auto_discover=1', 'upgrade', '--alldeps', 'dummy')
      provider.install
    end

    it 'installs a specific version' do
      resource[:ensure] = '0.2'
      allow(described_class).to receive(:pear).
        with('-D', 'auto_discover=1', 'upgrade', '--alldeps', '-f', 'dummy-0.2')
      provider.install
    end

    it 'installs from a specific source' do
      resource[:source] = 'pear.php.net/dummy'
      allow(described_class).to receive(:pear).
        with('-D', 'auto_discover=1', 'upgrade', '--alldeps', 'pear.php.net/dummy')
      provider.install
    end

    it 'installs a specific version from a specific source' do
      resource[:ensure] = '0.2'
      resource[:source] = 'pear.php.net/dummy'
      allow(described_class).to receive(:pear).
        with('-D', 'auto_discover=1', 'upgrade', '--alldeps', '-f', 'pear.php.net/dummy-0.2')
      provider.install
    end

    it 'uses the specified responsefile' do
      resource[:responsefile] = '/fake/pearresponse'
      allow(Puppet::Util::Execution).to receive(:execute).
        with(
          ['/fake/pear', '-D', 'auto_discover=1', 'upgrade', '--alldeps', 'dummy'],
          stdinfile: resource[:responsefile]
        )
      provider.install
    end

    it 'accepts install_options' do
      resource[:install_options] = ['--onlyreqdeps']
      allow(described_class).to receive(:pear).
        with('-D', 'auto_discover=1', 'upgrade', '--onlyreqdeps', 'dummy')
      provider.install
    end
  end

  describe '#query' do
    it 'queries information about one package' do
      allow(described_class).to receive(:pear).
        with('list', '-a').
        and_return File.read(File.join(MY_PATH, 'list_a'))

      resource[:name] = 'pear'
      expect(provider.query).to eq(
        name: 'PEAR', vendor: 'pear.php.net', ensure: '1.10.1', provider: :pear
      )
    end
  end

  describe '#latest' do
    it 'fetches the latest version available' do
      allow(described_class).to receive(:pear).
        with('remote-info', 'Benchmark').
        and_return File.read(File.join(MY_PATH, 'remote-info_benchmark'))

      resource[:name] = 'Benchmark'
      expect(provider.latest).to eq '1.2.9'
    end
  end

  describe '#uninstall' do
    it 'uninstalls a package' do
      allow(described_class).to receive(:pear).
        with('uninstall', resource[:name]).
        and_return('uninstall ok')
      provider.uninstall
    end

    it 'raises an error otherwise' do
      allow(described_class).to receive(:pear).
        with('uninstall', resource[:name]).
        and_return('unexpected output')
      expect { provider.uninstall }.to raise_error(Puppet::Error)
    end
  end

  describe '#update' do
    it 'ignores the resource version' do
      resource[:ensure] = '2.0'

      allow(described_class).to receive(:pear).
        with('-D', 'auto_discover=1', 'upgrade', '--alldeps', 'dummy')
      provider.update
    end
  end
end
