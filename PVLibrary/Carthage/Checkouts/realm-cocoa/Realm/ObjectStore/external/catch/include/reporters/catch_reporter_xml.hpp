/*
 *  Created by Phil on 28/10/2010.
 *  Copyright 2010 Two Blue Cubes Ltd. All rights reserved.
 *
 *  Distributed under the Boost Software License, Version 1.0. (See accompanying
 *  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 */
#ifndef TWOBLUECUBES_CATCH_REPORTER_XML_HPP_INCLUDED
#define TWOBLUECUBES_CATCH_REPORTER_XML_HPP_INCLUDED

#include "catch_reporter_bases.hpp"

#include "../internal/catch_capture.hpp"
#include "../internal/catch_reporter_registrars.hpp"
#include "../internal/catch_xmlwriter.hpp"
#include "../internal/catch_timer.h"

namespace Catch {
    class XmlReporter : public StreamingReporterBase {
    public:
        XmlReporter( ReporterConfig const& _config )
        :   StreamingReporterBase( _config ),
            m_xml(_config.stream()),
            m_sectionDepth( 0 )
        {
            m_reporterPrefs.shouldRedirectStdOut = true;
        }

        virtual ~XmlReporter() CATCH_OVERRIDE;

        static std::string getDescription() {
            return "Reports test results as an XML document";
        }

        virtual std::string getStylesheetRef() const {
            return std::string();
        }

        void writeSourceInfo( SourceLineInfo const& sourceInfo ) {
            m_xml
                .writeAttribute( "filename", sourceInfo.file )
                .writeAttribute( "line", sourceInfo.line );
        }

    public: // StreamingReporterBase

        virtual void noMatchingTestCases( std::string const& s ) CATCH_OVERRIDE {
            StreamingReporterBase::noMatchingTestCases( s );
        }

        virtual void testRunStarting( TestRunInfo const& testInfo ) CATCH_OVERRIDE {
            StreamingReporterBase::testRunStarting( testInfo );
            std::string stylesheetRef = getStylesheetRef();
            if( !stylesheetRef.empty() )
                m_xml.writeStylesheetRef( stylesheetRef );
            m_xml.startElement( "Catch" );
            if( !m_config->name().empty() )
                m_xml.writeAttribute( "name", m_config->name() );
        }

        virtual void testGroupStarting( GroupInfo const& groupInfo ) CATCH_OVERRIDE {
            StreamingReporterBase::testGroupStarting( groupInfo );
            m_xml.startElement( "Group" )
                .writeAttribute( "name", groupInfo.name );
        }

        virtual void testCaseStarting( TestCaseInfo const& testInfo ) CATCH_OVERRIDE {
            StreamingReporterBase::testCaseStarting(testInfo);
            m_xml.startElement( "TestCase" )
                .writeAttribute( "name", trim( testInfo.name ) )
                .writeAttribute( "description", testInfo.description )
                .writeAttribute( "tags", testInfo.tagsAsString );

            writeSourceInfo( testInfo.lineInfo );

            if ( m_config->showDurations() == ShowDurations::Always )
                m_testCaseTimer.start();
            m_xml.ensureTagClosed();
        }

        virtual void sectionStarting( SectionInfo const& sectionInfo ) CATCH_OVERRIDE {
            StreamingReporterBase::sectionStarting( sectionInfo );
            if( m_sectionDepth++ > 0 ) {
                m_xml.startElement( "Section" )
                    .writeAttribute( "name", trim( sectionInfo.name ) )
                    .writeAttribute( "description", sectionInfo.description );
                writeSourceInfo( sectionInfo.lineInfo );
                m_xml.ensureTagClosed();
            }
        }

        virtual void assertionStarting( AssertionInfo const& ) CATCH_OVERRIDE { }

        virtual bool assertionEnded( AssertionStats const& assertionStats ) CATCH_OVERRIDE {

            AssertionResult const& result = assertionStats.assertionResult;

            bool includeResults = m_config->includeSuccessfulResults() || !result.isOk();

            if( includeResults || result.getResultType() == ResultWas::Warning ) {
                // Print any info messages in <Info> tags.
                for( std::vector<MessageInfo>::const_iterator it = assertionStats.infoMessages.begin(), itEnd = assertionStats.infoMessages.end();
                     it != itEnd;
                     ++it ) {
                    if( it->type == ResultWas::Info && includeResults ) {
                        m_xml.scopedElement( "Info" )
                                .writeText( it->message );
                    } else if ( it->type == ResultWas::Warning ) {
                        m_xml.scopedElement( "Warning" )
                                .writeText( it->message );
                    }
                }
            }

            // Drop out if result was successful but we're not printing them.
            if( !includeResults && result.getResultType() != ResultWas::Warning )
                return true;


            // Print the expression if there is one.
            if( result.hasExpression() ) {
                m_xml.startElement( "Expression" )
                    .writeAttribute( "success", result.succeeded() )
                    .writeAttribute( "type", result.getTestMacroName() );

                writeSourceInfo( result.getSourceInfo() );

                m_xml.scopedElement( "Original" )
                    .writeText( result.getExpression() );
                m_xml.scopedElement( "Expanded" )
                    .writeText( result.getExpandedExpression() );
            }

            // And... Print a result applicable to each result type.
            switch( result.getResultType() ) {
                case ResultWas::ThrewException:
                    m_xml.startElement( "Exception" );
                    writeSourceInfo( result.getSourceInfo() );
                    m_xml.writeText( result.getMessage() );
                    m_xml.endElement();
                    break;
                case ResultWas::FatalErrorCondition:
                    m_xml.startElement( "FatalErrorCondition" );
                    writeSourceInfo( result.getSourceInfo() );
                    m_xml.writeText( result.getMessage() );
                    m_xml.endElement();
                    break;
                case ResultWas::Info:
                    m_xml.scopedElement( "Info" )
                        .writeText( result.getMessage() );
                    break;
                case ResultWas::Warning:
                    // Warning will already have been written
                    break;
                case ResultWas::ExplicitFailure:
                    m_xml.startElement( "Failure" );
                    writeSourceInfo( result.getSourceInfo() );
                    m_xml.writeText( result.getMessage() );
                    m_xml.endElement();
                    break;
                default:
                    break;
            }

            if( result.hasExpression() )
                m_xml.endElement();

            return true;
        }

        virtual void sectionEnded( SectionStats const& sectionStats ) CATCH_OVERRIDE {
            StreamingReporterBase::sectionEnded( sectionStats );
            if( --m_sectionDepth > 0 ) {
                XmlWriter::ScopedElement e = m_xml.scopedElement( "OverallResults" );
                e.writeAttribute( "successes", sectionStats.assertions.passed );
                e.writeAttribute( "failures", sectionStats.assertions.failed );
                e.writeAttribute( "expectedFailures", sectionStats.assertions.failedButOk );

                if ( m_config->showDurations() == ShowDurations::Always )
                    e.writeAttribute( "durationInSeconds", sectionStats.durationInSeconds );

                m_xml.endElement();
            }
        }

        virtual void testCaseEnded( TestCaseStats const& testCaseStats ) CATCH_OVERRIDE {
            StreamingReporterBase::testCaseEnded( testCaseStats );
            XmlWriter::ScopedElement e = m_xml.scopedElement( "OverallResult" );
            e.writeAttribute( "success", testCaseStats.totals.assertions.allOk() );

            if ( m_config->showDurations() == ShowDurations::Always )
                e.writeAttribute( "durationInSeconds", m_testCaseTimer.getElapsedSeconds() );

            if( !testCaseStats.stdOut.empty() )
                m_xml.scopedElement( "StdOut" ).writeText( trim( testCaseStats.stdOut ), false );
            if( !testCaseStats.stdErr.empty() )
                m_xml.scopedElement( "StdErr" ).writeText( trim( testCaseStats.stdErr ), false );

            m_xml.endElement();
        }

        virtual void testGroupEnded( TestGroupStats const& testGroupStats ) CATCH_OVERRIDE {
            StreamingReporterBase::testGroupEnded( testGroupStats );
            // TODO: Check testGroupStats.aborting and act accordingly.
            m_xml.scopedElement( "OverallResults" )
                .writeAttribute( "successes", testGroupStats.totals.assertions.passed )
                .writeAttribute( "failures", testGroupStats.totals.assertions.failed )
                .writeAttribute( "expectedFailures", testGroupStats.totals.assertions.failedButOk );
            m_xml.endElement();
        }

        virtual void testRunEnded( TestRunStats const& testRunStats ) CATCH_OVERRIDE {
            StreamingReporterBase::testRunEnded( testRunStats );
            m_xml.scopedElement( "OverallResults" )
                .writeAttribute( "successes", testRunStats.totals.assertions.passed )
                .writeAttribute( "failures", testRunStats.totals.assertions.failed )
                .writeAttribute( "expectedFailures", testRunStats.totals.assertions.failedButOk );
            m_xml.endElement();
        }

    private:
        Timer m_testCaseTimer;
        XmlWriter m_xml;
        int m_sectionDepth;
    };

     INTERNAL_CATCH_REGISTER_REPORTER( "xml", XmlReporter )

} // end namespace Catch

#endif // TWOBLUECUBES_CATCH_REPORTER_XML_HPP_INCLUDED
