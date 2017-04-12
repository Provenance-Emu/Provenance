class MD_4Way;

class MD_4Way_Shim final : public MD_Input_Device
{
	public:
	MD_4Way_Shim(unsigned nin, MD_4Way* p4w);
	virtual ~MD_4Way_Shim() override;
	virtual void StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix) override;
	virtual void Power(void) override;
	virtual void BeginTimePeriod(const int32 timestamp_base) override;
	virtual void EndTimePeriod(const int32 master_timestamp) override;
	virtual void UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted) override;

	private:
	unsigned n;
	MD_4Way* parent;
};

class MD_4Way
{
        public:
        MD_4Way();
        ~MD_4Way();

	void StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix);
	void Power(void);
        void BeginTimePeriod(const int32 timestamp_base);
        void EndTimePeriod(const int32 master_timestamp);

	INLINE MD_Input_Device* GetShim(unsigned n) { return &Shams[n]; }

	void UpdateBus(unsigned n, const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted);
	void SetSubPort(unsigned n, MD_Input_Device* d);

	private:
	MD_Input_Device* SubPort[4] = { nullptr, nullptr, nullptr, nullptr };
	MD_4Way_Shim Shams[2] = { { 0, this}, {1, this } };
	uint8 index;
};

