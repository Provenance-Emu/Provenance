/*
 *  Created by Phil on 5/11/2010.
 *  Copyright 2010 Two Blue Cubes Ltd. All rights reserved.
 *
 *  Distributed under the Boost Software License, Version 1.0. (See accompanying
 *  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 */
#ifndef TWOBLUECUBES_CATCH_LIST_HPP_INCLUDED
#define TWOBLUECUBES_CATCH_LIST_HPP_INCLUDED

#include "catch_commandline.hpp"
#include "catch_text.h"
#include "catch_console_colour.hpp"
#include "catch_interfaces_reporter.h"
#include "catch_test_spec_parser.hpp"

#include <limits>
#include <algorithm>

namespace Catch {

    inline std::size_t listTests( Config const& config ) {

        TestSpec testSpec = config.testSpec();
        if( config.testSpec().hasFilters() )
            Catch::cout() << "Matching test cases:\n";
        else {
            Catch::cout() << "All available test cases:\n";
            testSpec = TestSpecParser( ITagAliasRegistry::get() ).parse( "*" ).testSpec();
        }

        std::size_t matchedTests = 0;
        TextAttributes nameAttr, descAttr, tagsAttr;
        nameAttr.setInitialIndent( 2 ).setIndent( 4 );
        descAttr.setIndent( 4 );
        tagsAttr.setIndent( 6 );

        std::vector<TestCase> matchedTestCases = filterTests( getAllTestCasesSorted( config ), testSpec, config );
        for( std::vector<TestCase>::const_iterator it = matchedTestCases.begin(), itEnd = matchedTestCases.end();
                it != itEnd;
                ++it ) {
            matchedTests++;
            TestCaseInfo const& testCaseInfo = it->getTestCaseInfo();
            Colour::Code colour = testCaseInfo.isHidden()
                ? Colour::SecondaryText
                : Colour::None;
            Colour colourGuard( colour );

            Catch::cout() << Text( testCaseInfo.name, nameAttr ) << std::endl;
            if( config.listExtraInfo() ) {
                Catch::cout() << "    " << testCaseInfo.lineInfo << std::endl;
                std::string description = testCaseInfo.description;
                if( description.empty() )
                    description = "(NO DESCRIPTION)";
                Catch::cout() << Text( description, descAttr ) << std::endl;
            }
            if( !testCaseInfo.tags.empty() )
                Catch::cout() << Text( testCaseInfo.tagsAsString, tagsAttr ) << std::endl;
        }

        if( !config.testSpec().hasFilters() )
            Catch::cout() << pluralise( matchedTests, "test case" ) << '\n' << std::endl;
        else
            Catch::cout() << pluralise( matchedTests, "matching test case" ) << '\n' << std::endl;
        return matchedTests;
    }

    inline std::size_t listTestsNamesOnly( Config const& config ) {
        TestSpec testSpec = config.testSpec();
        if( !config.testSpec().hasFilters() )
            testSpec = TestSpecParser( ITagAliasRegistry::get() ).parse( "*" ).testSpec();
        std::size_t matchedTests = 0;
        std::vector<TestCase> matchedTestCases = filterTests( getAllTestCasesSorted( config ), testSpec, config );
        for( std::vector<TestCase>::const_iterator it = matchedTestCases.begin(), itEnd = matchedTestCases.end();
                it != itEnd;
                ++it ) {
            matchedTests++;
            TestCaseInfo const& testCaseInfo = it->getTestCaseInfo();
            if( startsWith( testCaseInfo.name, '#' ) )
               Catch::cout() << '"' << testCaseInfo.name << '"';
            else
               Catch::cout() << testCaseInfo.name;
            if ( config.listExtraInfo() )
                Catch::cout() << "\t@" << testCaseInfo.lineInfo;
            Catch::cout() << std::endl;
        }
        return matchedTests;
    }

    struct TagInfo {
        TagInfo() : count ( 0 ) {}
        void add( std::string const& spelling ) {
            ++count;
            spellings.insert( spelling );
        }
        std::string all() const {
            std::string out;
            for( std::set<std::string>::const_iterator it = spellings.begin(), itEnd = spellings.end();
                        it != itEnd;
                        ++it )
                out += "[" + *it + "]";
            return out;
        }
        std::set<std::string> spellings;
        std::size_t count;
    };

    inline std::size_t listTags( Config const& config ) {
        TestSpec testSpec = config.testSpec();
        if( config.testSpec().hasFilters() )
            Catch::cout() << "Tags for matching test cases:\n";
        else {
            Catch::cout() << "All available tags:\n";
            testSpec = TestSpecParser( ITagAliasRegistry::get() ).parse( "*" ).testSpec();
        }

        std::map<std::string, TagInfo> tagCounts;

        std::vector<TestCase> matchedTestCases = filterTests( getAllTestCasesSorted( config ), testSpec, config );
        for( std::vector<TestCase>::const_iterator it = matchedTestCases.begin(), itEnd = matchedTestCases.end();
                it != itEnd;
                ++it ) {
            for( std::set<std::string>::const_iterator  tagIt = it->getTestCaseInfo().tags.begin(),
                                                        tagItEnd = it->getTestCaseInfo().tags.end();
                    tagIt != tagItEnd;
                    ++tagIt ) {
                std::string tagName = *tagIt;
                std::string lcaseTagName = toLower( tagName );
                std::map<std::string, TagInfo>::iterator countIt = tagCounts.find( lcaseTagName );
                if( countIt == tagCounts.end() )
                    countIt = tagCounts.insert( std::make_pair( lcaseTagName, TagInfo() ) ).first;
                countIt->second.add( tagName );
            }
        }

        for( std::map<std::string, TagInfo>::const_iterator countIt = tagCounts.begin(),
                                                            countItEnd = tagCounts.end();
                countIt != countItEnd;
                ++countIt ) {
            std::ostringstream oss;
            oss << "  " << std::setw(2) << countIt->second.count << "  ";
            Text wrapper( countIt->second.all(), TextAttributes()
                                                    .setInitialIndent( 0 )
                                                    .setIndent( oss.str().size() )
                                                    .setWidth( CATCH_CONFIG_CONSOLE_WIDTH-10 ) );
            Catch::cout() << oss.str() << wrapper << '\n';
        }
        Catch::cout() << pluralise( tagCounts.size(), "tag" ) << '\n' << std::endl;
        return tagCounts.size();
    }

    inline std::size_t listReporters( Config const& /*config*/ ) {
        Catch::cout() << "Available reporters:\n";
        IReporterRegistry::FactoryMap const& factories = getRegistryHub().getReporterRegistry().getFactories();
        IReporterRegistry::FactoryMap::const_iterator itBegin = factories.begin(), itEnd = factories.end(), it;
        std::size_t maxNameLen = 0;
        for(it = itBegin; it != itEnd; ++it )
            maxNameLen = (std::max)( maxNameLen, it->first.size() );

        for(it = itBegin; it != itEnd; ++it ) {
            Text wrapper( it->second->getDescription(), TextAttributes()
                                                        .setInitialIndent( 0 )
                                                        .setIndent( 7+maxNameLen )
                                                        .setWidth( CATCH_CONFIG_CONSOLE_WIDTH - maxNameLen-8 ) );
            Catch::cout() << "  "
                    << it->first
                    << ':'
                    << std::string( maxNameLen - it->first.size() + 2, ' ' )
                    << wrapper << '\n';
        }
        Catch::cout() << std::endl;
        return factories.size();
    }

    inline Option<std::size_t> list( Config const& config ) {
        Option<std::size_t> listedCount;
        if( config.listTests() || ( config.listExtraInfo() && !config.listTestNamesOnly() ) )
            listedCount = listedCount.valueOr(0) + listTests( config );
        if( config.listTestNamesOnly() )
            listedCount = listedCount.valueOr(0) + listTestsNamesOnly( config );
        if( config.listTags() )
            listedCount = listedCount.valueOr(0) + listTags( config );
        if( config.listReporters() )
            listedCount = listedCount.valueOr(0) + listReporters( config );
        return listedCount;
    }

} // end namespace Catch

#endif // TWOBLUECUBES_CATCH_LIST_HPP_INCLUDED
